-- =============================================================
-- Consola del Tesoro — origin_region en trigger de registro
-- =============================================================
-- Al pasar 'origin_region' en el campo data de signUp en Flutter,
-- llega aquí como raw_user_meta_data->>'origin_region'.
-- Sin este cambio, el perfil se crea con origin_region = NULL
-- aunque el usuario lo seleccionara durante el registro.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, birth_date, origin_region)
  VALUES (
    new.id,
    COALESCE(
      NULLIF(trim(new.raw_user_meta_data->>'username'), ''),
      split_part(new.email, '@', 1)
    ),
    (new.raw_user_meta_data->>'birth_date')::date,
    NULLIF(trim(new.raw_user_meta_data->>'origin_region'), '')
  )
  ON CONFLICT (id) DO UPDATE
    SET
      username      = COALESCE(EXCLUDED.username,      profiles.username),
      birth_date    = COALESCE(EXCLUDED.birth_date,    profiles.birth_date),
      origin_region = COALESCE(EXCLUDED.origin_region, profiles.origin_region);
  RETURN new;
END;
$$;
