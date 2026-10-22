-- Evento Temporal: Cantabria (no especial)
-- Ejecutar en Supabase SQL Editor
--
-- Empieza: NOW() (en el momento de ejecutar el script)
-- Termina:  26 de octubre de 2026 a las 23:59 (hora de Madrid)
--
-- VERIFICA las coordenadas antes de ejecutar:
--   Coordenadas actuales: Peninsula de la Magdalena, Santander

DO $$
DECLARE
  v_hunt_id UUID := gen_random_uuid();
  v_clue_id UUID := gen_random_uuid();

  v_lat   DOUBLE PRECISION := 43.484815;   -- Latitud  (N)
  v_lng   DOUBLE PRECISION := -3.775640;   -- Longitud (W, negativo)
  v_radio INT              := 120;         -- Metros de radio para validacion GPS

BEGIN

  -- 1. Hunt temporal (no especial)
  INSERT INTO public.hunts (
    id, master_id, title, description, difficulty, reward_info,
    region, status, is_special, starts_at, ends_at
  ) VALUES (
    v_hunt_id,
    auth.uid(),
    'El Secreto de la Peninsula',
    'La peninsula guarda sus secretos entre acantilados y palacios. Tienes poco tiempo para descubrir lo que el mar sabe y los turistas pasan por alto.',
    'easy',
    'Medalla del Explorador Cantabro',
    'Cantabria',
    'active',
    FALSE,
    NOW(),
    '2026-10-26 23:59:59+01:00'
  );

  -- 2. Pista unica
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
    'Donde los reyes veraneaban y el mar besa la piedra, se alza un palacio que mira a dos bahias a la vez. No entres: la respuesta esta fuera, frente al agua.',
    ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326),
    v_radio,
    'El Palacio de la Magdalena esta en el extremo norte de la peninsula. Busca el mirador frente a la fachada principal.',
    100
  );

  RAISE NOTICE 'Hunt creado: %', v_hunt_id;
  RAISE NOTICE 'Pista creada: %', v_clue_id;

END $$;
