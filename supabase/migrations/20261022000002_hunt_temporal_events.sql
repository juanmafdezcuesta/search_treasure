-- Búsqueda del Tesoro — Eventos temporales con fecha de inicio y fin
ALTER TABLE public.hunts
  ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS ends_at   TIMESTAMPTZ NULL;
