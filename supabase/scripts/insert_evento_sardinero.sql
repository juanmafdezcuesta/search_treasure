-- Evento Especial: Playa del Sardinero, Santander (Cantabria)
-- Ejecutar en Supabase SQL Editor

DO $$
DECLARE
  v_hunt_id UUID := gen_random_uuid();
  v_clue_id UUID := gen_random_uuid();

  v_lat   DOUBLE PRECISION := 43.4789;   -- Latitud  Playa del Sardinero
  v_lng   DOUBLE PRECISION := -3.7847;   -- Longitud Playa del Sardinero
  v_radio INT              := 160;       -- Metros de radio para validacion GPS

BEGIN

  INSERT INTO public.hunts (
    id, master_id, title, description, difficulty, reward_info,
    region, status, is_special
  ) VALUES (
    v_hunt_id,
    auth.uid(),
    'La Marea del Sardinero',
    'El mar guarda secretos entre sus olas. Aventurate hasta la playa mas emblematica de Santander y descubre lo que las mareas han dejado atras. Un evento especial con vistas al Cantabrico.',
    'easy',
    'Premio Especial Sardinero',
    'Cantabria',
    'active',
    TRUE
  );

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
    'Donde la ciudad se quita los zapatos y el Cantabrico besa la arena dorada. Busca el punto donde las olas llegan mas lejos sin mojar a nadie. Alli esta el tesoro que el mar no se llevo.',
    ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326),
    v_radio,
    'Dirigete al paseo maritimo frente a la Primera Playa del Sardinero, cerca del Hotel Real.',
    100
  );

  RAISE NOTICE 'Hunt creado: %', v_hunt_id;
  RAISE NOTICE 'Pista creada: %', v_clue_id;

END $$;
