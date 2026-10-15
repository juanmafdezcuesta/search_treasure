-- =============================================================
-- Consola del Tesoro — Vista leaderboard + Rate limiting GPS
-- =============================================================

-- ─── 1. Vista leaderboard ────────────────────────────────────────────────────
-- Consumida por RankingScreen (columnas: profile_id, username, avatar_url,
-- origin_region, total_hunts, xp). total_hunts = hunts distintos donde el
-- jugador tiene al menos una pista validada por el admin.
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard AS
SELECT
  p.id              AS profile_id,
  p.username,
  p.avatar_url,
  p.origin_region,
  p.xp,
  COALESCE(h.total_hunts, 0)::int AS total_hunts
FROM public.profiles p
LEFT JOIN (
  SELECT user_id, COUNT(DISTINCT hunt_id) AS total_hunts
  FROM public.user_progress
  WHERE status = 'validated'
  GROUP BY user_id
) h ON h.user_id = p.id;

-- RLS: la vista no necesita su propia política; hereda las de profiles.
-- Los datos de user_progress son solo el conteo (sin exponer foto_url ni clue_id).

-- ─── 2. Rate limiting server-side en check_proximity ──────────────────────────
-- Añadimos last_proximity_check a profiles para registrar el último intento GPS.
-- El cliente ya aplica 30s de cooldown; aquí añadimos 25s en el servidor como
-- segunda capa que no puede saltarse desde el cliente.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_proximity_check timestamptz;

-- ─── 3. Redefinición de check_proximity con rate limiting ─────────────────────
CREATE OR REPLACE FUNCTION public.check_proximity(
  p_clue_id uuid,
  p_lat     double precision,
  p_lng     double precision
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id  uuid := auth.uid();
  v_last     timestamptz;
  v_target   geography;
  v_radius   integer;
  v_dist     double precision;
BEGIN
  -- ── Rate limit: máximo 1 llamada cada 25 segundos por usuario ─────────────
  SELECT last_proximity_check INTO v_last
  FROM profiles WHERE id = v_user_id;

  IF v_last IS NOT NULL AND
     EXTRACT(EPOCH FROM (now() - v_last)) < 25 THEN
    RETURN false;  -- demasiado pronto; el cliente mostrará su propio mensaje
  END IF;

  -- Actualizar timestamp ANTES de la comprobación para bloquear intentos paralelos
  UPDATE profiles SET last_proximity_check = now() WHERE id = v_user_id;

  -- ── Comprobar proximidad ──────────────────────────────────────────────────
  SELECT location, radius_meters
  INTO   v_target, v_radius
  FROM   clues WHERE id = p_clue_id;

  IF NOT FOUND THEN RETURN false; END IF;

  v_dist := ST_Distance(
    v_target,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  );

  RETURN v_dist <= v_radius;
END;
$$;
