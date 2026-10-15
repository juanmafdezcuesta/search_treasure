-- =============================================================
-- Consola del Tesoro – XP por llegada a cada pista (GPS OK)
-- =============================================================
-- Regla: al validar la ubicación GPS de una pista se otorga XP inmediato.
--   Posición 1 → 10 XP, 2 → 9 XP, …, 10 → 1 XP, resto → 1 XP
--   El registro es idempotente: no puede otorgarse dos veces por la misma pista.

-- ─── Tabla de registro de premios GPS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.clue_xp_awards (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  clue_id     uuid        NOT NULL REFERENCES public.clues(id) ON DELETE CASCADE,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  xp_awarded  int         NOT NULL,
  position    int         NOT NULL,  -- 1 = primero en llegar
  awarded_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (clue_id, user_id)
);

ALTER TABLE public.clue_xp_awards ENABLE ROW LEVEL SECURITY;

-- Cada usuario solo puede ver sus propios premios
DROP POLICY IF EXISTS "user_own_xp_awards" ON public.clue_xp_awards;
CREATE POLICY "user_own_xp_awards" ON public.clue_xp_awards
  FOR SELECT USING (auth.uid() = user_id);

-- ─── RPC: award_proximity_xp ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.award_proximity_xp(
  p_clue_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position    int;
  v_xp          int;
  v_xp_exist    int;
  v_pos_exist   int;
BEGIN
  -- Idempotente: si ya se otorgó XP para esta pista, devolver valores existentes
  SELECT xp_awarded, position
  INTO   v_xp_exist, v_pos_exist
  FROM   clue_xp_awards
  WHERE  clue_id = p_clue_id AND user_id = p_user_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'xp_awarded',      v_xp_exist,
      'position',        v_pos_exist,
      'already_awarded', true
    );
  END IF;

  -- Calcular posición: cuántos usuarios ya tienen XP para esta pista + 1
  SELECT COUNT(*) + 1 INTO v_position
  FROM   clue_xp_awards
  WHERE  clue_id = p_clue_id;

  -- XP según posición: top 10 → 10,9,8…1; resto → 1
  v_xp := CASE WHEN v_position <= 10 THEN 11 - v_position ELSE 1 END;

  -- Registrar el premio
  INSERT INTO clue_xp_awards (clue_id, user_id, xp_awarded, position)
  VALUES (p_clue_id, p_user_id, v_xp, v_position);

  -- Acumular en el perfil del usuario
  UPDATE profiles
  SET    xp = COALESCE(xp, 0) + v_xp
  WHERE  id = p_user_id;

  RETURN jsonb_build_object(
    'xp_awarded',      v_xp,
    'position',        v_position,
    'already_awarded', false
  );
END;
$$;
