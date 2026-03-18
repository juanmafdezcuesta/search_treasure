-- =============================================================
-- Consola del Tesoro – Perfil: comunidad autónoma de origen
-- =============================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS origin_region TEXT;

CREATE INDEX IF NOT EXISTS profiles_origin_region_idx
  ON public.profiles (origin_region);

