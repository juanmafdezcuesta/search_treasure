-- Añade la columna is_special a la tabla hunts
-- Permite marcar hunts como "Eventos Especiales / Patrocinados" (monetización B2B)
ALTER TABLE public.hunts
  ADD COLUMN IF NOT EXISTS is_special BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE public.hunts SET is_special = FALSE WHERE is_special IS NULL;
