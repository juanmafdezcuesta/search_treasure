-- =============================================================
-- Búsqueda del Tesoro – XP en perfiles
-- =============================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS xp INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS profiles_xp_idx
  ON public.profiles (xp DESC);

