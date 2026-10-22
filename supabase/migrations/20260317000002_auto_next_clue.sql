-- =============================================================
-- Búsqueda del Tesoro – Auto: activar siguiente pista al validar
-- =============================================================
-- Ajusta approve_validation para que:
--  - al aprobar una pista, inserte automáticamente la siguiente (pending)
--    si existe una pista con step_order + 1 en public.clues.
--  - solo marque el hunt como completed si realmente no hay más pistas.

CREATE OR REPLACE FUNCTION public.approve_validation(
    p_progress_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id     UUID;
    v_hunt_id     UUID;
    v_clue_id     UUID;
    v_step_order  SMALLINT;
    v_next_clue   UUID;
BEGIN
    -- Recuperar datos del progress y verificar que el llamante es el master
    SELECT up.user_id, up.hunt_id, up.clue_id
    INTO   v_user_id, v_hunt_id, v_clue_id
    FROM   public.user_progress up
    JOIN   public.hunts h ON h.id = up.hunt_id
    WHERE  up.id       = p_progress_id
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

    -- Step actual
    SELECT c.step_order
    INTO   v_step_order
    FROM   public.clues c
    WHERE  c.id = v_clue_id;

    -- Siguiente pista por step_order
    SELECT c.id
    INTO   v_next_clue
    FROM   public.clues c
    WHERE  c.hunt_id = v_hunt_id
      AND  c.step_order = v_step_order + 1
    LIMIT 1;

    -- Si existe siguiente pista, crear progreso pending (idempotente).
    IF v_next_clue IS NOT NULL THEN
        INSERT INTO public.user_progress (user_id, hunt_id, clue_id, status)
        VALUES (v_user_id, v_hunt_id, v_next_clue, 'pending')
        ON CONFLICT (user_id, hunt_id, clue_id) DO NOTHING;
    ELSE
        -- Si no hay siguiente pista → marcar el hunt como completado por este jugador
        UPDATE public.hunts
        SET    status    = 'completed',
               winner_id = v_user_id
        WHERE  id = v_hunt_id
          AND  status = 'active';  -- Solo si nadie ganó antes
    END IF;

    RETURN jsonb_build_object(
        'approved',       true,
        'next_clue_id',   v_next_clue,        -- NULL = victoria
        'hunt_completed', v_next_clue IS NULL
    );
END;
$$;

