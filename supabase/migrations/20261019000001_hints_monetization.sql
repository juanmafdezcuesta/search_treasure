-- =============================================================
-- Búsqueda del Tesoro — Sistema de Pistas Extra (Monetización)
-- =============================================================
-- Añade columnas hint_text / hint_cost a clues,
-- crea la tabla unlocked_hints con RLS,
-- y la RPC SECURITY DEFINER unlock_clue_hint.

-- ─── 1. Columnas en clues ──────────────────────────────────────────────────
ALTER TABLE public.clues
  ADD COLUMN IF NOT EXISTS hint_text text,
  ADD COLUMN IF NOT EXISTS hint_cost int4 NOT NULL DEFAULT 100;

-- ─── 2. Tabla de pistas desbloqueadas ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.unlocked_hints (
  user_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  clue_id     uuid        NOT NULL REFERENCES public.clues(id)    ON DELETE CASCADE,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, clue_id)
);

ALTER TABLE public.unlocked_hints ENABLE ROW LEVEL SECURITY;

-- Sólo el propio usuario puede leer sus desbloqueos
CREATE POLICY "unlocked_hints_select_own"
  ON public.unlocked_hints FOR SELECT
  USING (auth.uid() = user_id);

-- Sólo el propio usuario puede insertar (la RPC lo hace por seguridad)
CREATE POLICY "unlocked_hints_insert_own"
  ON public.unlocked_hints FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ─── 3. RPC unlock_clue_hint ───────────────────────────────────────────────
-- Flujo:
--   a) Si ya desbloqueada → devuelve hint_text sin cobrar.
--   b) Verifica saldo suficiente en profiles.wallet_balance.
--   c) Resta el coste, inserta en unlocked_hints, devuelve hint_text + nuevo saldo.
CREATE OR REPLACE FUNCTION public.unlock_clue_hint(p_clue_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID  := auth.uid();
  v_hint_text   TEXT;
  v_hint_cost   INT4;
  v_balance     INT4;
  v_new_balance INT4;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No autenticado.';
  END IF;

  -- Obtener datos de la pista
  SELECT hint_text, hint_cost
  INTO   v_hint_text, v_hint_cost
  FROM   public.clues
  WHERE  id = p_clue_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pista no encontrada.';
  END IF;

  IF v_hint_text IS NULL OR trim(v_hint_text) = '' THEN
    RAISE EXCEPTION 'Esta pista no tiene ayuda adicional.';
  END IF;

  -- Idempotente: si ya desbloqueada, devolver sin cobrar
  IF EXISTS (
    SELECT 1 FROM public.unlocked_hints
    WHERE  user_id = v_user_id AND clue_id = p_clue_id
  ) THEN
    RETURN jsonb_build_object(
      'hint_text',       v_hint_text,
      'already_unlocked', true,
      'cost_paid',        0
    );
  END IF;

  -- Verificar saldo
  SELECT COALESCE(wallet_balance, 0)
  INTO   v_balance
  FROM   public.profiles
  WHERE  id = v_user_id;

  IF v_balance < v_hint_cost THEN
    RAISE EXCEPTION 'Saldo insuficiente';
  END IF;

  -- Descontar saldo e insertar registro
  v_new_balance := v_balance - v_hint_cost;

  UPDATE public.profiles
  SET    wallet_balance = v_new_balance
  WHERE  id = v_user_id;

  INSERT INTO public.unlocked_hints (user_id, clue_id)
  VALUES (v_user_id, p_clue_id);

  RETURN jsonb_build_object(
    'hint_text',        v_hint_text,
    'already_unlocked', false,
    'cost_paid',        v_hint_cost,
    'new_balance',      v_new_balance
  );
END;
$$;
