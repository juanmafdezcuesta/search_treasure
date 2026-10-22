-- =============================================================
-- Búsqueda del Tesoro – Hunts por región
-- =============================================================

ALTER TABLE public.hunts
ADD COLUMN IF NOT EXISTS region TEXT;

-- Índice para filtrado por región (y status)
CREATE INDEX IF NOT EXISTS hunts_region_status_idx
  ON public.hunts (region, status);

