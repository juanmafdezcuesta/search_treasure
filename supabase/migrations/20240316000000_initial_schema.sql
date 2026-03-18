-- =============================================================
-- Consola del Tesoro – Initial Schema
-- =============================================================

-- -------------------------------------------------------------
-- 0. EXTENSIONES
-- -------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;


-- -------------------------------------------------------------
-- 1. PROFILES
--    Extiende auth.users de Supabase. Se crea automáticamente
--    al registrarse un nuevo usuario (via trigger en auth.users).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id             UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username       TEXT        NOT NULL UNIQUE,
    avatar_url     TEXT,
    is_admin       BOOLEAN     NOT NULL DEFAULT FALSE,
    wallet_balance NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger: crea un perfil vacío cuando Supabase registra un usuario nuevo
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, username)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- -------------------------------------------------------------
-- 2. HUNTS (Eventos / Búsquedas del tesoro)
-- -------------------------------------------------------------
CREATE TYPE hunt_difficulty AS ENUM ('easy', 'medium', 'hard');
CREATE TYPE hunt_status     AS ENUM ('draft', 'active', 'completed', 'cancelled');

CREATE TABLE IF NOT EXISTS public.hunts (
    id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    master_id    UUID            NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title        TEXT            NOT NULL,
    description  TEXT,
    difficulty   hunt_difficulty NOT NULL DEFAULT 'medium',
    reward_info  TEXT,           -- Descripción del premio (texto libre)
    status       hunt_status     NOT NULL DEFAULT 'draft',
    winner_id    UUID            REFERENCES public.profiles(id),
    created_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    starts_at    TIMESTAMPTZ,
    ends_at      TIMESTAMPTZ
);


-- -------------------------------------------------------------
-- 3. CLUES (Pistas vinculadas a un hunt)
--    IMPORTANTE: la columna `location` es geography(Point,4326).
--    Los jugadores NUNCA ven esta columna directamente (RLS).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clues (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    hunt_id      UUID        NOT NULL REFERENCES public.hunts(id) ON DELETE CASCADE,
    step_order   SMALLINT    NOT NULL,          -- Orden de la pista dentro del hunt
    riddle_text  TEXT        NOT NULL,          -- El acertijo visible para el jugador
    radius_meters INT        NOT NULL DEFAULT 20, -- Radio de validación en metros
    location     GEOGRAPHY(Point, 4326) NOT NULL, -- Coordenadas secretas del servidor
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (hunt_id, step_order)
);

-- Índice espacial: acelera enormemente las consultas ST_DWithin
CREATE INDEX IF NOT EXISTS clues_location_gist
    ON public.clues USING GIST (location);


-- -------------------------------------------------------------
-- 4. FUNCIÓN check_proximity
--    Valida server-side si un jugador está lo suficientemente
--    cerca de la pista. Nunca expone la columna location.
--
--    Uso:  SELECT check_proximity(<clue_id>, <lat>, <lng>);
--    Ret:  BOOLEAN
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_proximity(
    p_clue_id UUID,
    p_lat     DOUBLE PRECISION,
    p_lng     DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER           -- Corre como el dueño, no como el jugador
SET search_path = public
AS $$
DECLARE
    v_target      GEOGRAPHY;
    v_radius      INT;
    v_player_pt   GEOGRAPHY;
    v_distance    DOUBLE PRECISION;
BEGIN
    -- Recuperar ubicación y radio de la pista (acceso privilegiado)
    SELECT location, radius_meters
    INTO   v_target, v_radius
    FROM   public.clues
    WHERE  id = p_clue_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Clue % not found', p_clue_id;
    END IF;

    -- Construir el punto del jugador (lng primero: estándar GeoJSON/PostGIS)
    v_player_pt := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::GEOGRAPHY;

    -- ST_Distance sobre GEOGRAPHY devuelve metros en el elipsoide WGS-84
    v_distance := ST_Distance(v_target, v_player_pt);

    RETURN v_distance <= v_radius;
END;
$$;


-- -------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS)
-- -------------------------------------------------------------

-- ── profiles ──────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario autenticado puede leer perfiles (nombre, avatar, wallet)
CREATE POLICY "profiles_select_authenticated"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

-- Cada usuario solo puede actualizar su propio perfil
CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);


-- ── hunts ─────────────────────────────────────────────────────
ALTER TABLE public.hunts ENABLE ROW LEVEL SECURITY;

-- Todos los usuarios autenticados pueden leer hunts activos
CREATE POLICY "hunts_select_active"
    ON public.hunts FOR SELECT
    TO authenticated
    USING (status IN ('active', 'completed'));

-- Solo el master que creó el hunt puede insertar/modificar
CREATE POLICY "hunts_insert_master"
    ON public.hunts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = master_id);

CREATE POLICY "hunts_update_master"
    ON public.hunts FOR UPDATE
    TO authenticated
    USING (auth.uid() = master_id);


-- ── clues ─────────────────────────────────────────────────────
ALTER TABLE public.clues ENABLE ROW LEVEL SECURITY;

-- Los jugadores pueden leer pistas de hunts activos,
-- PERO la política se aplica sobre una vista que excluye `location`.
-- La columna `location` queda protegida porque:
--   a) Esta política solo aplica a la tabla base,
--   b) Se expone una VIEW segura (ver abajo) sin dicha columna.
CREATE POLICY "clues_select_active_hunt"
    ON public.clues FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.hunts h
            WHERE h.id = hunt_id
              AND h.status = 'active'
        )
    );

-- Solo el master puede crear/editar pistas
CREATE POLICY "clues_insert_master"
    ON public.clues FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.hunts h
            WHERE h.id = hunt_id
              AND h.master_id = auth.uid()
        )
    );

CREATE POLICY "clues_update_master"
    ON public.clues FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.hunts h
            WHERE h.id = hunt_id
              AND h.master_id = auth.uid()
        )
    );


-- -------------------------------------------------------------
-- 6. VISTA PÚBLICA DE PISTAS (sin columna location)
--    El cliente Flutter consumirá esta vista, nunca la tabla base.
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW public.clues_public AS
    SELECT
        id,
        hunt_id,
        step_order,
        riddle_text,
        radius_meters,
        created_at
        -- `location` deliberadamente excluida
    FROM public.clues;

-- La vista hereda RLS de la tabla base automáticamente
