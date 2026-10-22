-- =============================================================
-- Búsqueda del Tesoro – Progreso de jugadores y Storage
-- =============================================================

-- -------------------------------------------------------------
-- 1. TABLA user_progress
--    Registra el avance de cada jugador pista a pista.
--    Una fila por (user_id, hunt_id, clue_id).
-- -------------------------------------------------------------
CREATE TYPE progress_status AS ENUM ('pending', 'validated');

CREATE TABLE IF NOT EXISTS public.user_progress (
    id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID            NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
    hunt_id      UUID            NOT NULL REFERENCES public.hunts(id)       ON DELETE CASCADE,
    clue_id      UUID            NOT NULL REFERENCES public.clues(id)       ON DELETE CASCADE,
    status       progress_status NOT NULL DEFAULT 'pending',
    photo_url    TEXT,                          -- URL pública del bucket validation_photos
    validated_at TIMESTAMPTZ,                   -- Se rellena cuando status → 'validated'
    created_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Un jugador no puede tener dos filas para la misma pista en el mismo hunt
    UNIQUE (user_id, hunt_id, clue_id)
);

-- Índices de consulta frecuente
CREATE INDEX IF NOT EXISTS user_progress_user_hunt_idx
    ON public.user_progress (user_id, hunt_id);

CREATE INDEX IF NOT EXISTS user_progress_status_idx
    ON public.user_progress (status);


-- -------------------------------------------------------------
-- 2. RLS – user_progress
-- -------------------------------------------------------------
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- Cada jugador solo ve su propio progreso
CREATE POLICY "progress_select_own"
    ON public.user_progress FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Solo puede insertar filas propias
CREATE POLICY "progress_insert_own"
    ON public.user_progress FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Solo puede actualizar filas propias (ej. subir foto o cambiar status)
CREATE POLICY "progress_update_own"
    ON public.user_progress FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- El master del hunt puede leer el progreso de todos los jugadores de ese hunt
CREATE POLICY "progress_select_master"
    ON public.user_progress FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.hunts h
            WHERE h.id = hunt_id
              AND h.master_id = auth.uid()
        )
    );


-- -------------------------------------------------------------
-- 3. BUCKET DE STORAGE – validation_photos
--    Se crea mediante SQL usando la API interna de Supabase Storage.
--    El bucket es PRIVADO: solo se accede mediante URLs firmadas.
-- -------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'validation_photos',
    'validation_photos',
    false,                               -- Privado: URLs firmadas requeridas
    5242880,                             -- Límite: 5 MB por foto
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Política Storage: el jugador puede subir fotos a su propia carpeta
--   Ruta esperada: validation_photos/{user_id}/{progress_id}.jpg
CREATE POLICY "storage_upload_own"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'validation_photos'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- El jugador puede leer sus propias fotos
CREATE POLICY "storage_read_own"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'validation_photos'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- El master puede leer todas las fotos de validación
CREATE POLICY "storage_read_master"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'validation_photos'
        AND EXISTS (
            -- La foto pertenece a un progress de un hunt que gestiona este master
            SELECT 1
            FROM   public.user_progress up
            JOIN   public.hunts h ON h.id = up.hunt_id
            WHERE  h.master_id   = auth.uid()
              AND  up.photo_url  LIKE '%' || name || '%'
        )
    );


-- -------------------------------------------------------------
-- 4. FUNCIÓN get_active_clue(p_user_id, p_hunt_id)
--    Devuelve la primera pista cuyo step_order NO está validado
--    por el usuario en este hunt.
--
--    Lógica:
--      · Busca la pista de menor step_order que NO tiene una fila
--        en user_progress con status = 'validated' para este usuario.
--      · Si todas las pistas están validadas → devuelve NULL (hunt completado).
--
--    Devuelve: TABLE (clue_id, step_order, riddle_text, radius_meters)
--              La columna 'location' se omite deliberadamente.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_active_clue(
    p_user_id UUID,
    p_hunt_id UUID
)
RETURNS TABLE (
    clue_id       UUID,
    step_order    SMALLINT,
    riddle_text   TEXT,
    radius_meters INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id          AS clue_id,
        c.step_order,
        c.riddle_text,
        c.radius_meters
    FROM public.clues c
    WHERE c.hunt_id = p_hunt_id
      AND NOT EXISTS (
          SELECT 1
          FROM   public.user_progress up
          WHERE  up.user_id  = p_user_id
            AND  up.hunt_id  = p_hunt_id
            AND  up.clue_id  = c.id
            AND  up.status   = 'validated'
      )
    ORDER BY c.step_order ASC
    LIMIT 1;
END;
$$;


-- -------------------------------------------------------------
-- 5. FUNCIÓN validate_clue_with_photo(p_clue_id, p_lat, p_lng, p_photo_url)
--    Combina check_proximity + registro de progreso en un solo RPC.
--    El cliente llama esto cuando el usuario pulsa "¡Estoy aquí!" + sube foto.
--
--    Devuelve: JSON { success: bool, message: text, next_clue_id: uuid | null }
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_clue_with_photo(
    p_clue_id   UUID,
    p_lat       DOUBLE PRECISION,
    p_lng       DOUBLE PRECISION,
    p_photo_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID := auth.uid();
    v_hunt_id   UUID;
    v_is_near   BOOLEAN;
    v_progress  UUID;
    v_next_clue UUID;
BEGIN
    -- Recuperar el hunt al que pertenece esta pista
    SELECT hunt_id INTO v_hunt_id
    FROM   public.clues
    WHERE  id = p_clue_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Pista no encontrada.');
    END IF;

    -- Validar proximidad (reutiliza la función del schema inicial)
    v_is_near := public.check_proximity(p_clue_id, p_lat, p_lng);

    IF NOT v_is_near THEN
        RETURN jsonb_build_object('success', false, 'message', 'Demasiado lejos del objetivo.');
    END IF;

    -- Insertar o actualizar progreso → status 'validated'
    INSERT INTO public.user_progress (user_id, hunt_id, clue_id, status, photo_url, validated_at)
    VALUES (v_user_id, v_hunt_id, p_clue_id, 'validated', p_photo_url, NOW())
    ON CONFLICT (user_id, hunt_id, clue_id)
    DO UPDATE SET
        status       = 'validated',
        photo_url    = EXCLUDED.photo_url,
        validated_at = NOW()
    RETURNING id INTO v_progress;

    -- Buscar la siguiente pista activa
    SELECT clue_id INTO v_next_clue
    FROM   public.get_active_clue(v_user_id, v_hunt_id);

    RETURN jsonb_build_object(
        'success',       true,
        'message',       'Pista validada correctamente.',
        'progress_id',   v_progress,
        'next_clue_id',  v_next_clue   -- NULL si era la última pista
    );
END;
$$;
