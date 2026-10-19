-- =============================================================
-- Consola del Tesoro — Control de edad (RGPD, edad mínima 16)
-- =============================================================

-- ─── 1. Columna birth_date en profiles ────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS birth_date date;

-- ─── 2. Actualizar la función de trigger para leer birth_date del metadata ─
-- La función handle_new_user crea el perfil cuando se registra un usuario.
-- Al añadir birth_date al campo `data` de signUp en Flutter, llega aquí como
-- raw_user_meta_data->>'birth_date'. El cast a DATE es seguro: si el valor
-- fuese null o inválido se almacena NULL (no lanza excepción).
--
-- IMPORTANTE: Si el nombre de tu función de trigger es distinto de
-- 'handle_new_user', cámbialo abajo antes de ejecutar esta migración.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, birth_date)
  VALUES (
    new.id,
    COALESCE(
      NULLIF(trim(new.raw_user_meta_data->>'username'), ''),
      split_part(new.email, '@', 1)
    ),
    (new.raw_user_meta_data->>'birth_date')::date
  )
  ON CONFLICT (id) DO UPDATE
    SET
      username   = COALESCE(EXCLUDED.username,   profiles.username),
      birth_date = COALESCE(EXCLUDED.birth_date, profiles.birth_date);
  RETURN new;
END;
$$;

-- El trigger en sí no necesita modificarse (already fires AFTER INSERT ON auth.users).
-- Si por algún motivo no existe, créalo con:
--
-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
