-- =============================================================
-- Consola del Tesoro – Perfil público: trofeos (solo lectura)
-- =============================================================
-- RLS de user_progress solo permite leer progreso propio (o masters).
-- Para el "perfil público" exponemos un RPC seguro (SECURITY DEFINER)
-- que devuelve únicamente hunts validados para un usuario.

CREATE OR REPLACE FUNCTION public.get_public_trophies(
  p_profile_id UUID
)
RETURNS TABLE (
  hunt_id UUID,
  hunt_title TEXT,
  hunt_region TEXT,
  validated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado.';
  END IF;

  RETURN QUERY
  SELECT
    h.id AS hunt_id,
    h.title AS hunt_title,
    h.region AS hunt_region,
    up.validated_at
  FROM public.user_progress up
  JOIN public.hunts h ON h.id = up.hunt_id
  WHERE up.user_id = p_profile_id
    AND up.status = 'validated'
    AND up.validated_at IS NOT NULL
  ORDER BY up.validated_at DESC;
END;
$$;

