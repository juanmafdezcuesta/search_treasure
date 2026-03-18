-- =============================================================
-- Consola del Tesoro – Funciones de administración (Master)
-- =============================================================

-- -------------------------------------------------------------
-- 1. get_pending_validations(p_hunt_id)
--    Devuelve las validaciones pendientes de un hunt con toda
--    la información que necesita la AdminScreen:
--      · Datos del progress (id, photo_url, fecha)
--      · Nombre y avatar del jugador
--      · Número y texto de la pista
--
--    Solo el master del hunt puede llamar a esta función.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pending_validations(
    p_hunt_id UUID
)
RETURNS TABLE (
    progress_id   UUID,
    user_id       UUID,
    username      TEXT,
    avatar_url    TEXT,
    clue_id       UUID,
    step_order    SMALLINT,
    riddle_text   TEXT,
    photo_url     TEXT,
    submitted_at  TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Verificar que el llamante es el master de este hunt
    IF NOT EXISTS (
        SELECT 1 FROM public.hunts
        WHERE id = p_hunt_id AND master_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para administrar este hunt.';
    END IF;

    RETURN QUERY
    SELECT
        up.id          AS progress_id,
        up.user_id,
        pr.username,
        pr.avatar_url,
        up.clue_id,
        c.step_order,
        c.riddle_text,
        up.photo_url,
        up.created_at  AS submitted_at
    FROM   public.user_progress up
    JOIN   public.profiles pr ON pr.id = up.user_id
    JOIN   public.clues    c  ON c.id  = up.clue_id
    WHERE  up.hunt_id = p_hunt_id
      AND  up.status  = 'pending'
    ORDER BY up.created_at ASC;  -- El más antiguo primero (FIFO)
END;
$$;


-- -------------------------------------------------------------
-- 2. approve_validation(p_progress_id)
--    · Marca el progress como 'validated'.
--    · Devuelve el clue_id de la siguiente pista (para notificar
--      al jugador), o NULL si era la última.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_validation(
    p_progress_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID;
    v_hunt_id   UUID;
    v_clue_id   UUID;
    v_next_clue UUID;
BEGIN
    -- Recuperar datos del progress y verificar que el llamante es el master
    SELECT up.user_id, up.hunt_id, up.clue_id
    INTO   v_user_id, v_hunt_id, v_clue_id
    FROM   public.user_progress up
    JOIN   public.hunts h ON h.id = up.hunt_id
    WHERE  up.id     = p_progress_id
      AND  h.master_id = auth.uid()
      AND  up.status   = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Validación no encontrada o sin permisos.';
    END IF;

    -- Marcar como validada
    UPDATE public.user_progress
    SET    status       = 'validated',
           validated_at = NOW()
    WHERE  id = p_progress_id;

    -- Buscar la siguiente pista activa para este jugador
    SELECT clue_id INTO v_next_clue
    FROM   public.get_active_clue(v_user_id, v_hunt_id);

    -- Si no hay siguiente pista → marcar el hunt como completado por este jugador
    IF v_next_clue IS NULL THEN
        UPDATE public.hunts
        SET    status    = 'completed',
               winner_id = v_user_id
        WHERE  id = v_hunt_id
          AND  status = 'active';  -- Solo si nadie ganó antes
    END IF;

    RETURN jsonb_build_object(
        'approved',      true,
        'next_clue_id',  v_next_clue,     -- NULL = victoria
        'hunt_completed', v_next_clue IS NULL
    );
END;
$$;


-- -------------------------------------------------------------
-- 3. reject_validation(p_progress_id, p_reason)
--    · Elimina el intento del jugador (puede volver a intentarlo).
--    · Guarda el motivo de rechazo en una tabla de log opcional.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_validation(
    p_progress_id UUID,
    p_reason      TEXT DEFAULT 'La foto no es válida.'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id  UUID;
    v_photo    TEXT;
BEGIN
    -- Verificar permisos del master
    SELECT up.user_id, up.photo_url
    INTO   v_user_id, v_photo
    FROM   public.user_progress up
    JOIN   public.hunts h ON h.id = up.hunt_id
    WHERE  up.id       = p_progress_id
      AND  h.master_id = auth.uid()
      AND  up.status   = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Validación no encontrada o sin permisos.';
    END IF;

    -- Eliminar el intento → el jugador puede volver a intentarlo
    DELETE FROM public.user_progress WHERE id = p_progress_id;

    RETURN jsonb_build_object(
        'rejected',  true,
        'user_id',   v_user_id,
        'reason',    p_reason
    );
END;
$$;
