-- =============================================================
-- Consola del Tesoro – RPC: unirse a un hunt + reset de progreso
-- =============================================================

-- -------------------------------------------------------------
-- 1) join_hunt(p_hunt_title)
--    - Busca un hunt activo por título (o el primero activo si NULL/vacío)
--    - Inserta en user_progress la primera pista disponible como 'pending'
--    - Idempotente: si ya existe la fila, no duplica
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_hunt(
  p_hunt_title TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_hunt_id UUID;
  v_clue_id UUID;
  v_inserted BOOLEAN := false;
  v_row_count INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado.';
  END IF;

  IF p_hunt_title IS NOT NULL AND btrim(p_hunt_title) <> '' THEN
    SELECT id
    INTO v_hunt_id
    FROM public.hunts
    WHERE status = 'active'
      AND title = p_hunt_title
    ORDER BY created_at ASC
    LIMIT 1;
  ELSE
    SELECT id
    INTO v_hunt_id
    FROM public.hunts
    WHERE status = 'active'
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  IF v_hunt_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No hay ningún tesoro activo en este momento.'
    );
  END IF;

  -- Obtener la primera pista disponible (por step_order).
  SELECT id
  INTO v_clue_id
  FROM public.clues
  WHERE hunt_id = v_hunt_id
  ORDER BY step_order ASC
  LIMIT 1;

  IF v_clue_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No hay pistas configuradas para este tesoro'
    );
  END IF;

  INSERT INTO public.user_progress (user_id, hunt_id, clue_id, status)
  VALUES (v_user_id, v_hunt_id, v_clue_id, 'pending')
  ON CONFLICT (user_id, hunt_id, clue_id) DO NOTHING;

  GET DIAGNOSTICS v_row_count = ROW_COUNT;
  v_inserted := v_row_count > 0;

  RETURN jsonb_build_object(
    'success', true,
    'hunt_id', v_hunt_id,
    'clue_id', v_clue_id,
    'inserted', v_inserted
  );
END;
$$;

-- -------------------------------------------------------------
-- 2) reset_my_progress(p_hunt_id)
--    - Solo admins (profiles.is_admin = true)
--    - Borra el progreso del propio usuario para ese hunt
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reset_my_progress(
  p_hunt_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN := false;
  v_deleted INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado.';
  END IF;

  SELECT COALESCE(is_admin, false)
  INTO v_is_admin
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'No tienes permisos para resetear progreso.';
  END IF;

  DELETE FROM public.user_progress
  WHERE user_id = v_user_id
    AND hunt_id = p_hunt_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'deleted', v_deleted
  );
END;
$$;

