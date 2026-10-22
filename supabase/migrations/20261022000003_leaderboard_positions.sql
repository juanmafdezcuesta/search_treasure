-- Búsqueda del Tesoro — Ranking de posiciones por hunt (modelo multi-ganador)
-- Los hunts ya NO se cierran cuando gana el primero: permanecen abiertos
-- hasta ends_at y acumulan completions con posición y puntos escalonados.

-- ─── 1. Columnas en user_progress ────────────────────────────────────────────
ALTER TABLE public.user_progress
  ADD COLUMN IF NOT EXISTS finish_rank   INT NULL,
  ADD COLUMN IF NOT EXISTS points_earned INT NOT NULL DEFAULT 0;

-- ─── 2. Refactor de approve_validation ───────────────────────────────────────
-- Cambios vs versión anterior:
--   · NO cambia hunts.status a 'completed'
--   · NO escribe winner_id
--   · Calcula finish_rank contando los ya rankeados en ese hunt
--   · Asigna puntos escalonados y los suma al perfil del jugador
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
    v_finish_rank INT;
    v_points      INT;
BEGIN
    -- Verificar que el llamante es el master del hunt y la pista está pendiente
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

    SELECT c.step_order INTO v_step_order
    FROM   public.clues c WHERE c.id = v_clue_id;

    -- ¿Hay siguiente pista?
    SELECT c.id INTO v_next_clue
    FROM   public.clues c
    WHERE  c.hunt_id    = v_hunt_id
      AND  c.step_order = v_step_order + 1
    LIMIT 1;

    IF v_next_clue IS NOT NULL THEN
        -- Pista intermedia → desbloquear la siguiente
        INSERT INTO public.user_progress (user_id, hunt_id, clue_id, status)
        VALUES (v_user_id, v_hunt_id, v_next_clue, 'pending')
        ON CONFLICT (user_id, hunt_id, clue_id) DO NOTHING;

    ELSE
        -- Pista final → calcular posición de llegada
        -- (cuenta usuarios con finish_rank ya asignado en este hunt; el actual aún no lo tiene)
        SELECT COUNT(*) + 1 INTO v_finish_rank
        FROM   public.user_progress
        WHERE  hunt_id     = v_hunt_id
          AND  finish_rank IS NOT NULL;

        -- Puntos escalonados
        v_points := CASE
            WHEN v_finish_rank = 1   THEN 500
            WHEN v_finish_rank <= 3  THEN 250
            WHEN v_finish_rank <= 10 THEN 100
            WHEN v_finish_rank <= 50 THEN 50
            ELSE 5
        END;

        -- Guardar posición y puntos en el registro de progreso final
        UPDATE public.user_progress
        SET    finish_rank   = v_finish_rank,
               points_earned = v_points
        WHERE  id = p_progress_id;

        -- Sumar XP al perfil del jugador
        UPDATE public.profiles
        SET    xp = COALESCE(xp, 0) + v_points
        WHERE  id = v_user_id;
    END IF;

    RETURN jsonb_build_object(
        'approved',       true,
        'next_clue_id',   v_next_clue,
        'hunt_completed', v_next_clue IS NULL,
        'finish_rank',    v_finish_rank,
        'points_earned',  v_points
    );
END;
$$;

-- ─── 3. RPC get_hunt_leaderboard ─────────────────────────────────────────────
-- Devuelve los jugadores que completaron el hunt, ordenados por posición.
-- SECURITY DEFINER permite leer user_progress de otros usuarios (cross-user).
CREATE OR REPLACE FUNCTION public.get_hunt_leaderboard(p_hunt_id UUID)
RETURNS TABLE (
    user_id       UUID,
    username      TEXT,
    avatar_url    TEXT,
    finish_rank   INT,
    points_earned INT,
    validated_at  TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        up.user_id,
        p.username,
        p.avatar_url,
        up.finish_rank,
        up.points_earned,
        up.validated_at
    FROM  public.user_progress up
    JOIN  public.profiles p ON p.id = up.user_id
    WHERE up.hunt_id     = p_hunt_id
      AND up.finish_rank IS NOT NULL
    ORDER BY up.finish_rank ASC;
END;
$$;
