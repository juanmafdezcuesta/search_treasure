-- =============================================================
-- Consola del Tesoro – Gameplay fixes
-- =============================================================

-- ─── 1. get_clue_distance ────────────────────────────────────────────────────
-- Devuelve la distancia en metros al punto de la pista SIN revelar coordenadas.
-- Útil para orientar al jugador cuando está demasiado lejos.
CREATE OR REPLACE FUNCTION public.get_clue_distance(
  p_clue_id uuid,
  p_lat     double precision,
  p_lng     double precision
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target geography;
  v_dist   double precision;
BEGIN
  SELECT location INTO v_target FROM clues WHERE id = p_clue_id;
  IF NOT FOUND THEN RETURN -1; END IF;

  v_dist := ST_Distance(
    v_target,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  );
  RETURN v_dist::integer;
END;
$$;


-- ─── 2. submit_clue_photo ────────────────────────────────────────────────────
-- Reemplaza el INSERT directo del cliente en user_progress.
-- Solo permite el envío si el GPS fue validado previamente (clue_xp_awards).
CREATE OR REPLACE FUNCTION public.submit_clue_photo(
  p_clue_id   uuid,
  p_photo_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_hunt_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado.';
  END IF;

  -- GPS debe haberse validado antes (hay entrada en clue_xp_awards)
  IF NOT EXISTS (
    SELECT 1 FROM clue_xp_awards
    WHERE clue_id = p_clue_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'GPS no validado para esta pista.';
  END IF;

  SELECT hunt_id INTO v_hunt_id FROM clues WHERE id = p_clue_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pista no encontrada.';
  END IF;

  INSERT INTO user_progress (user_id, hunt_id, clue_id, status, photo_url)
  VALUES (v_user_id, v_hunt_id, p_clue_id, 'pending', p_photo_url)
  ON CONFLICT (user_id, hunt_id, clue_id) DO UPDATE
    SET photo_url  = EXCLUDED.photo_url,
        status     = 'pending',
        created_at = NOW();

  RETURN jsonb_build_object('submitted', true);
END;
$$;
