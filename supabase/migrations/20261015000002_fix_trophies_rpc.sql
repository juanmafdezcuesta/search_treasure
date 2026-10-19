-- =============================================================
-- Consola del Tesoro — Fix get_public_trophies
-- =============================================================
-- Problema: la versión anterior filtraba con `validated_at IS NOT NULL`,
-- lo que excluía entradas aprobadas con la versión original de
-- approve_validation (que no seteaba validated_at).
-- El leaderboard contaba esas entradas correctamente (solo checa status)
-- pero get_public_trophies no las devolvía → trofeo no aparecía en perfil.
-- Fix: eliminar el filtro validated_at IS NOT NULL y usar COALESCE para
-- el orden, de modo que entradas sin validated_at usen created_at.

CREATE OR REPLACE FUNCTION public.get_public_trophies(
  p_profile_id UUID
)
RETURNS TABLE (
  hunt_id      UUID,
  hunt_title   TEXT,
  hunt_region  TEXT,
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
  SELECT DISTINCT ON (h.id)
    h.id           AS hunt_id,
    h.title        AS hunt_title,
    h.region       AS hunt_region,
    up.validated_at
  FROM public.user_progress up
  JOIN public.hunts h ON h.id = up.hunt_id
  WHERE up.user_id = p_profile_id
    AND up.status  = 'validated'
  ORDER BY h.id, COALESCE(up.validated_at, up.created_at) DESC;
END;
$$;
