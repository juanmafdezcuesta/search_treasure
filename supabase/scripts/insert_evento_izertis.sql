-- Evento Especial Patrocinado: Izertis Gijon
-- Ejecutar en Supabase SQL Editor
--
-- VERIFICA las coordenadas antes de ejecutar:
--   Abre Google Maps -> busca "Izertis Gijon" o "Av. Jardin Botanico 1345, Gijon"
--   -> clic derecho sobre el edificio -> copia lat,lng y reemplaza los valores.
--   Coordenadas actuales: estimadas (PCTGijon Zona Intra, Gijon)

DO $$
DECLARE
  v_hunt_id UUID := gen_random_uuid();
  v_clue_id UUID := gen_random_uuid();

  -- Ajusta aqui si las coordenadas no son exactas
  v_lat   DOUBLE PRECISION := 43.526343214377995;  -- Latitud  (N)
  v_lng   DOUBLE PRECISION := -5.623798677371092;  -- Longitud (W, negativo)
  v_radio INT              := 200;      -- Metros de radio para validacion GPS

BEGIN

  -- 1. Hunt especial patrocinado
  INSERT INTO public.hunts (
    id, master_id, title, description, difficulty, reward_info,
    region, status, is_special
  ) VALUES (
    v_hunt_id,
    auth.uid(),   -- usa el usuario con el que ejecutas el script en Supabase
    'Reto Izertis: La Huella Digital',
    'Una expedicion por el corazon tecnologico de Asturias. Descubre los secretos del Parque Cientifico y Tecnologico de Gijon en este evento patrocinado por Izertis.',
    'medium',
    'Premio Especial Izertis',
    'Asturias',
    'active',
    TRUE
  );

  -- 2. Pista del juego (acertijo que el jugador debe resolver llegando al lugar)
  INSERT INTO public.clues (
    id, hunt_id, step_order,
    riddle_text,
    location,
    radius_meters,
    hint_text,
    hint_cost
  ) VALUES (
    v_clue_id,
    v_hunt_id,
    1,
    'En el parque donde el codigo se escribe en asturiano digital, busca el edificio cuyo nombre suena a certeza. Los datos fluyen como el Nalon, pero aqui la corriente es de fibra optica.',
    ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326),
    v_radio,
    'Busca el logotipo en la fachada principal del edificio Izertis, dentro del PCTGijon.',
    100
  );

  RAISE NOTICE 'Hunt creado: %', v_hunt_id;
  RAISE NOTICE 'Pista creada: %', v_clue_id;

END $$;
