-- =============================================================
-- Búsqueda del Tesoro – Fix: perfiles para usuarios anónimos
-- =============================================================
-- En sign-ins anónimos, `auth.users.email` puede venir NULL.
-- El trigger original intentaba derivar username desde el email,
-- lo que rompe el NOT NULL/UNIQUE de `profiles.username`.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text;
BEGIN
  v_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    CASE
      WHEN NEW.email IS NOT NULL AND NEW.email <> '' THEN split_part(NEW.email, '@', 1)
      ELSE NULL
    END,
    'Invitado_' || substring(replace(NEW.id::text, '-', ''), 1, 10)
  );

  INSERT INTO public.profiles (id, username)
  VALUES (NEW.id, v_username);

  RETURN NEW;
END;
$$;

