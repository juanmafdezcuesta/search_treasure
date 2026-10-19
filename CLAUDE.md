# Reglas del Proyecto: consoleTesoro (Search Treasure)

## Stack Tecnológico
- **Frontend**: Flutter (iOS + Android + Web), SDK >=3.3.0
- **Backend**: Supabase (Auth, PostgreSQL + PostGIS, Storage, RPCs con SECURITY DEFINER)
- **Mapas**: OpenStreetMap vía `flutter_map` con tiles OSM estándar
- **GPS**: `geolocator`
- **Otros**: `flutter_animate`, `confetti`, `image_picker`, `google_fonts` (Poppins)
- **Pendiente**: `mobile_scanner ^5.1.0` en pubspec (comentado) — QR en VictoryScreen

## Arquitectura
Feature-first con capa de datos ligera. No Riverpod/Bloc/Provider — cada pantalla es `StatefulWidget` con estado propio. Estado global en `AppSession` (singleton). Navegación con `Navigator.push` vanilla.

```
lib/
├── core/           # config, models, session, theme
├── data/           # datasources/supabase, repositories
└── features/       # auth, admin, hunts, map, profile, ranking, regions
```

### AppSession (singleton global)
- `ValueNotifier<Profile?> profile` — perfil del usuario autenticado
- `ValueNotifier<bool> isAdmin` — acceso al panel de admin
- `ValueNotifier<ThemeMode> themeMode` — tema oscuro/claro/sistema; persiste mientras dura la sesión; se selecciona desde ProfileScreen

## Modelos Clave
- **Hunt**: `id, title, description, difficulty (easy/medium/hard), rewardInfo, region, status, avgRating, ratingCount`
- **Profile**: `id, username, avatarUrl, originRegion, xp, isAdmin, walletBalance, birthDate` + getters computados `level`, `xpInCurrentLevel`, `xpForNextLevel`
- **ActiveClue**: `clueId, huntId, stepOrder, riddleText, radiusMeters` — las coordenadas GPS NUNCA llegan al cliente (RPC con SECURITY DEFINER)
- **PendingValidation**: datos de admin para aprobar/rechazar fotos enviadas

## Pantallas y Flujo
| Pantalla | Propósito |
|---|---|
| AuthGate | Router de auth; escucha `onAuthStateChange`; arranca `AppSession.refreshProfile` |
| LoginScreen | Email+contraseña + toggle login/registro + acceso anónimo; errores en español; validación de edad ≥ 16 con `showDatePicker`; términos con checkbox; `birth_date` se pasa en `signUp data` y en upsert de `profiles` |
| RegionSelectionScreen | Home post-login; cuadrícula 17 CCAA; acceso a Ranking y Profile desde AppBar |
| HuntListScreen | Tres secciones: **DISPONIBLES** (activos), **PRÓXIMAMENTE** (draft, sin tap), **COMPLETADAS** (muted, tachado, badge ganador/lock). Cards activas con franja izquierda de color según dificultad + sombra de color. Sin `Opacity` wrapper — colores muted explícitos. Carga paralela con `Future.wait`. Filtra hunts ya terminados por el usuario con `getUserFullyCompletedHuntIds()`. |
| MapScreen | Núcleo del juego — ver sección Gameplay más abajo |
| AdminScreen | Panel del Maestro: 2 tabs — Pendientes (ValidationCard: aprobar/rechazar) y Validadas (ganadores) |
| ProfileScreen | Editar username, avatar_url, origin_region (dropdown 17 CCAA) + selector de ThemeMode (Sistema/Claro/Oscuro); cerrar sesión |
| PublicProfileScreen | Carnet de Aventurero (nivel, XP barra, fecha ingreso, trofeos como sellos, badge "Viajero" si hunt fuera de CCAA de origen) |
| RankingScreen | Nacional / Mi Comunidad; podio top-3 oro/plata/bronce; navega a PublicProfileScreen al tocar |

### Gameplay — MapScreen (detalle)
`MapScreen` recibe `huntId`, `huntTitle` y `region`. Estado interno con `_MapScreenState with TickerProviderStateMixin`.

**Flujo de una pista:**
1. `_loadData()` → `getActiveClue` + `countHuntClues` en paralelo → `checkProgressStatus` (restaura estado `submitted` si ya había foto) → `getClueHintCost` + `isHintUnlocked` → reanuda polling si corresponde
2. `_onCheckIn()` → rate limit 30 s → `check_proximity` RPC (timeout 10 s) → si OK: `_awardClueXp()` (XP toast) → estado `gpsValidated`
3. `_onTakePhoto()` → `ImagePicker` → upload a Storage (timeout 30 s) → `submitCluePhoto` RPC (timeout 15 s) → inicia polling
4. `_startPolling()` → `Timer.periodic` 5 s → `checkProgressStatus` + `checkHuntStatus` → si `validated`: confeti + `_loadNextClue()`
5. Si `getActiveClue` devuelve null → `_VictoryPanel` (todas las pistas completadas)

**Características:**
- Indicador "Pista X / Y" en ClueBottomPanel
- Distancia al objetivo en metros cuando GPS falla (RPC `get_clue_distance`)
- Rate limiting 30 s en cliente (`_lastCheckInAttempt`) + 25 s en servidor
- XP toast inmediato "+X XP · Posición #N" al validar GPS
- Polling 5 s post-foto; confeti y avance solo al detectar `status=validated`
- Estado `submitted` persistente: al volver a la hunt se detecta foto pendiente y reanuda polling
- Diálogo "¡Alguien se ha adelantado!" si otro jugador ganó mientras se juega
- **Pista extra (monetización)**: botón en `ClueBottomPanel` para desbloquear hint pagando `wallet_balance`; estado `_hintCost / _hintText / _hintLoading`; se resetea al avanzar de pista

### ClueBottomPanel — parámetros clave
`riddleText, actionState, onCheckIn, onTakePhoto, stepOrder, totalSteps, distanceMeters, hintCost, hintText, hintLoading, onUnlockHint`

`_buildHintSection()`: oculto si `hintCost == 0`, botón gold si no desbloqueado, tarjeta gold con el texto si ya desbloqueado.

## RPCs Supabase (todas SECURITY DEFINER)
| RPC | Retorna | Descripción |
|---|---|---|
| `get_active_clue(p_user_id, p_hunt_id)` | TABLE | Primera pista sin validar; excluye columna `location` |
| `check_proximity(p_clue_id, p_lat, p_lng)` | bool | Valida GPS server-side con PostGIS ST_Distance + rate limit 25 s en BD |
| `award_proximity_xp(p_clue_id, p_user_id)` | jsonb | Registra llegada GPS e ingresa XP por posición; idempotente vía `clue_xp_awards` |
| `get_clue_distance(p_clue_id, p_lat, p_lng)` | integer | Metros al objetivo sin revelar coordenadas; -1 si no existe |
| `submit_clue_photo(p_clue_id, p_photo_url)` | jsonb | Inserta en `user_progress` solo si existe entrada en `clue_xp_awards` (gate de seguridad) |
| `approve_validation(p_progress_id)` | jsonb | Marca validated, activa siguiente pista, completa hunt si es la última (+500 XP) |
| `reject_validation(p_progress_id, p_reason)` | jsonb | Elimina la entrada; el jugador puede reintentar |
| `get_pending_validations(p_hunt_id)` | TABLE | Solo accesible al master del hunt |
| `get_public_trophies(p_profile_id)` | TABLE | Hunts completados de cualquier perfil; usa COALESCE(validated_at, created_at) |
| `unlock_clue_hint(p_clue_id)` | jsonb | Descuenta `wallet_balance`, inserta en `unlocked_hints`; idempotente (no cobra si ya desbloqueada). Devuelve `hint_text, already_unlocked, cost_paid, new_balance` |

**Tablas**: `hunts`, `clues` (+ `hint_text`, `hint_cost`), `user_progress`, `profiles` (+ `birth_date`, `wallet_balance`, `last_proximity_check`), `clue_xp_awards`, `unlocked_hints`
**Vistas**: `leaderboard` (migración `20261015000001`), `clues_public`
**Storage bucket**: `validation_photos` (privado, 5 MB, JPEG/PNG/WebP)

### Migraciones clave
| Archivo | Contenido |
|---|---|
| `20240316000002_admin_functions.sql` | approve/reject_validation v1 |
| `20260317000007_reward_xp_on_hunt_completion.sql` | approve_validation v2: validated_at, hunt completed, +500 XP, winner_id |
| `20261015000001_leaderboard_and_rate_limit.sql` | Vista leaderboard + rate limiting 25 s server-side en check_proximity |
| `20261015000002_fix_trophies_rpc.sql` | get_public_trophies: elimina filtro validated_at IS NOT NULL, añade DISTINCT ON |
| `20261019000001_hints_monetization.sql` | Columnas `hint_text`/`hint_cost` en clues, tabla `unlocked_hints` con RLS, RPC `unlock_clue_hint` |
| `20261019000002_birth_date.sql` | Columna `birth_date DATE` en profiles + actualización de trigger `handle_new_user` para leerla de `raw_user_meta_data` |

## Tema y Estilos
- Siempre usar `AppColors` definidos en `lib/core/theme/app_theme.dart`
- **Paleta dark**: `backgroundDark #050914`, `surfaceDark #0D1320`, `cardDark #111827`
- **Paleta light**: `backgroundLight #F8F9FA`, `surfaceLight #FFFFFF`, `cardLight #F1F3F5`
- **Acentos** (iguales en ambos temas): `accentCyan #00E5CC`, `accentCoral #FF6B4A`, `accentGold #FFD700`, `success #00E676`, `error #FF3D3D`, `accentFuchsia #FF3366`
- **Texto dark**: `textPrimary #FFFFFF`, `textSecondary #8B949E`
- **Texto light**: `textPrimaryLight #111111`, `textSecondaryLight #6B7280`
- Tipografía: Poppins (Google Fonts). Botones mínimo 48×48px.
- **Soporte dual dark/light**: `AppTheme.dark` y `AppTheme.light` en MaterialApp; controlado por `AppSession.themeMode`; el usuario lo elige desde ProfileScreen
- Textos en **español**

## Diseño UI/UX
- Pantalla de mapa: 80% mapa + 20% panel inferior (ClueBottomPanel); FAB anclado en área de mapa (no solapa el panel)
- **Cards de HuntListScreen**: activas con franja izquierda de color de dificultad + sombra coloreada + borde coloreado; draft/completadas sin `Opacity` — colores muted explícitos sobre `surfaceDark`
- Microinteracciones: confeti/vibración en check-in; feedback visual inmediato (verde=acierto, naranja/rojo=fallo)
- XP snackbar con margin `bottom: 360` para no solapar badges del panel inferior
- Pantalla de victoria: banner de celebración + bloqueo del evento

## Sistema XP
- **Por GPS validado**: posición 1→10 XP, 2→9 XP, …, 10→1 XP; resto→1 XP. `clue_xp_awards` como fuente de verdad (gate para `submit_clue_photo`).
- **Por completar hunt**: +500 XP al aprobar la última foto (en `approve_validation`).
- **Nivel**: `level = (xp ~/ 1000) + 1`. `xpForNextLevel = 1000` (constante).

## Sistema de Monetización de Pistas
- Cada pista en `clues` tiene `hint_cost INT (DEFAULT 100)` y `hint_text TEXT` (nullable).
- `wallet_balance` en `profiles` funciona como monedero interno.
- Flujo de desbloqueo: `HuntDatasource.unlockHint()` → RPC `unlock_clue_hint` → descuenta balance, inserta en `unlocked_hints`, devuelve texto.
- En `MapScreen._loadData()`: si la pista ya estaba desbloqueada (`isHintUnlocked`), se recupera el texto directamente sin coste.
- Si `hint_cost == 0` o `hint_text` es null, el botón de pista no aparece.

## Seguridad y Cumplimiento
- Validación de victoria **exclusivamente en servidor** (nunca en cliente)
- Coordenadas GPS nunca expuestas al cliente (SECURITY DEFINER en RPCs)
- Foto solo enviable si GPS fue validado: `submit_clue_photo` comprueba `clue_xp_awards`
- Rate limiting **doble capa**: 30 s en cliente + 25 s en servidor (campo `last_proximity_check` en profiles)
- **Control de edad RGPD**: edad mínima 16 años validada en cliente antes del registro; `birth_date` almacenada en `profiles`; pasada en `signUp data` para que el trigger la persista también en el flujo de confirmación por email
- Detección de Mock Location (GPS falso) — **pendiente** (no implementada)
- `env.json` con credenciales incluido en assets (la anon key de Supabase es segura por diseño)

## Funcionalidades Planificadas (pendientes)
- `mobile_scanner ^5.1.0` ya en pubspec (comentado): escaneo QR en VictoryScreen
- Tutorial de onboarding (3 pasos con ilustraciones) antes del registro
- Detección de Mock Location con aviso al usuario
- Notificación al resto de jugadores cuando se completa un hunt
- Sistema de Escuadrón real (tabla `squads` + distribución de XP entre miembros)
- Recarga de `wallet_balance` (pasarela de pago o compra in-app)
- ~~Rate limiting server-side en `check_proximity`~~ ✅ `20261015000001`
- ~~Vista `leaderboard` como migración SQL~~ ✅ `20261015000001`
- ~~Términos y Condiciones con checkbox~~ ✅ implementado en LoginScreen
- ~~Hunts completados no aparecen en DISPONIBLES~~ ✅ `getUserFullyCompletedHuntIds()`
- ~~Sistema de pistas extra de pago~~ ✅ `20261019000001` + ClueBottomPanel + MapScreen
- ~~Control de edad RGPD (≥16 años)~~ ✅ `20261019000002` + LoginScreen
- ~~Soporte tema claro/oscuro~~ ✅ `AppTheme.light` + `AppSession.themeMode` + ProfileScreen

## Notas Técnicas
- **Flutter Web**: no usar `dart:io` (crash en web). Usar `dart:async` para `TimeoutException`. Comprobar antes de añadir imports de plataforma.
- **Web debug sobre ngrok**: carga ~959 archivos JS separados, muy lento. Usar `--release` para pruebas móviles. Fallback de pantalla de carga en `web/index.html`: 30 s.
- **Supabase anon key en ngrok**: añadir `https://*.ngrok-free.app/**` en Supabase → Auth → URL Configuration → Allowed Origins.
- **Cards sin `Opacity` wrapper**: usar colores con `.withOpacity()` directamente en cada propiedad; el `Opacity` widget afecta a toda la subtree incluyendo las sombras.
- **`IntrinsicHeight` en cards**: necesario para que la franja lateral de color (`Container(width:4)`) se extienda al 100% de la altura de la card.

## Config
- Supabase URL/key: `assets/env.json` (fallback) o `--dart-define` (preferido en CI)
- App name: `consola_tesoro`, versión 1.0.0+1
