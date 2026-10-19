# Reglas del Proyecto: consoleTesoro (Search Treasure)

## Stack Tecnológico
- **Frontend**: Flutter (iOS + Android + Web), SDK >=3.3.0
- **Backend**: Supabase (Auth, PostgreSQL + PostGIS, Storage, RPCs con SECURITY DEFINER)
- **Mapas**: OpenStreetMap vía `flutter_map` con tiles CartoDB Dark
- **GPS**: `geolocator`
- **Otros**: `flutter_animate`, `confetti`, `image_picker`, `google_fonts` (Poppins)
- **Pendiente**: `mobile_scanner ^5.1.0` en pubspec (comentado) — QR en VictoryScreen

## Arquitectura
Feature-first con capa de datos ligera. No Riverpod/Bloc/Provider — cada pantalla es `StatefulWidget` con estado propio. Estado global en `AppSession` (singleton con `ValueNotifier<Profile?>` e `isAdmin`). Navegación con `Navigator.push` vanilla.

```
lib/
├── core/           # config, models, session, theme
├── data/           # datasources/supabase, repositories
└── features/       # auth, admin, hunts, map, profile, ranking, regions
```

## Modelos Clave
- **Hunt**: `id, title, description, difficulty (easy/medium/hard), rewardInfo, region, status, avgRating, ratingCount`
- **Profile**: `id, username, avatarUrl, originRegion, xp, isAdmin, walletBalance` + getters computados `level`, `xpInCurrentLevel`, `xpForNextLevel`
- **ActiveClue**: `clueId, huntId, stepOrder, riddleText, radiusMeters` — las coordenadas GPS NUNCA llegan al cliente (RPC con SECURITY DEFINER)
- **PendingValidation**: datos de admin para aprobar/rechazar fotos enviadas

## Pantallas y Flujo
| Pantalla | Propósito |
|---|---|
| AuthGate | Router de auth; escucha `onAuthStateChange`; arranca `AppSession.refreshProfile` |
| LoginScreen | Email+contraseña + toggle login/registro + acceso anónimo; errores en español |
| RegionSelectionScreen | Home post-login; cuadrícula 17 CCAA; acceso a Ranking y Profile desde AppBar |
| HuntListScreen | Dos secciones: DISPONIBLES (activos) + COMPLETADAS (con opacidad, tachado, badge ganador/lock). Carga paralela con `Future.wait`. |
| MapScreen | Núcleo del juego — ver sección Gameplay más abajo |
| AdminScreen | Panel del Maestro: 2 tabs — Pendientes (ValidationCard: aprobar/rechazar) y Validadas (ganadores) |
| ProfileScreen | Editar username, avatar_url, origin_region (dropdown 17 CCAA); cerrar sesión |
| PublicProfileScreen | Carnet de Aventurero (nivel, XP barra, fecha ingreso, trofeos como sellos, badge "Viajero" si hunt fuera de CCAA de origen) |
| RankingScreen | Nacional / Mi Comunidad; podio top-3 oro/plata/bronce; navega a PublicProfileScreen al tocar |

### Gameplay — MapScreen (detalle)
`MapScreen` recibe `huntId` y `huntTitle`. Estado interno con `_MapScreenState with TickerProviderStateMixin`.

**Flujo de una pista:**
1. `_loadData()` → `getActiveClue` + `countHuntClues` en paralelo → comprueba `checkProgressStatus` para restaurar estado `submitted` + reanudar polling si ya había foto pendiente
2. `_onCheckIn()` → rate limit 30 s → `check_proximity` RPC (timeout 10 s) → si OK: `_awardClueXp()` (XP toast) → estado `gpsValidated`
3. `_onTakePhoto()` → `ImagePicker` → upload a Storage (timeout 30 s) → `submitCluePhoto` RPC (timeout 15 s) → inicia polling
4. `_startPolling()` → `Timer.periodic` 5 s → `checkProgressStatus` → si `validated`: confeti + `_loadNextClue()`
5. Si `getActiveClue` devuelve null → `_VictoryPanel` (todas las pistas completadas)

**Características:**
- Indicador "Pista X / Y" en ClueBottomPanel
- Distancia al objetivo en metros cuando GPS falla (RPC `get_clue_distance`)
- Rate limiting 30 s en cliente (toast countdown)
- XP toast inmediato "+X XP · Posición #N" al validar GPS
- Polling 5 s post-foto; confeti y avance solo al detectar `status=validated`
- Estado `submitted` persistente: al volver a la hunt se detecta foto pendiente y reanuda polling
- AppBar: gradiente semitransparente `flexibleSpace` para legibilidad sobre tiles OSM claros

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
| `get_public_trophies(p_profile_id)` | TABLE | Hunts completados de cualquier perfil; usa COALESCE(validated_at, created_at) para compatibilidad con entries antiguas sin validated_at |

**Tablas**: `hunts`, `clues`, `user_progress`, `profiles`, `clue_xp_awards`
**Vistas**: `leaderboard` (migración en repo: `20261015000001`), `clues_public`
**Storage bucket**: `validation_photos` (privado, 5 MB, JPEG/PNG/WebP)

### Migraciones clave
| Archivo | Contenido |
|---|---|
| `20240316000002_admin_functions.sql` | approve/reject_validation v1 (sin validated_at, sin marcar hunt completed) |
| `20260317000007_reward_xp_on_hunt_completion.sql` | approve_validation v2: sets validated_at, marca hunt completed, +500 XP, winner_id |
| `20261015000001_leaderboard_and_rate_limit.sql` | Vista leaderboard + rate limiting 25 s server-side en check_proximity |
| `20261015000002_fix_trophies_rpc.sql` | get_public_trophies: elimina filtro validated_at IS NOT NULL, añade DISTINCT ON |

## Tema y Estilos
- Siempre usar `AppColors` definidos en `lib/core/theme/app_theme.dart`
- Paleta: `backgroundDark #0D1117`, `accentCyan #00E5CC`, `accentCoral #FF6B4A`, `accentGold #FFD700`, `success #00E676`, `error #FF3D3D`
- Tipografía: Poppins (Google Fonts). Botones mínimo 48×48px. Alto contraste para uso exterior.
- Tema oscuro como único modo (ahorra batería con GPS activo)
- Textos en **español**

## Diseño UI/UX (del análisis funcional)
- Pantalla de mapa: 80% mapa + 20% UI (FAB grande + menú inferior simple)
- Pistas en Bottom Sheets con bordes redondeados y texto grande
- Microinteracciones: confeti/vibración en check-in; feedback visual inmediato (verde=acierto, naranja/rojo=fallo)
- Pantalla de victoria: banner de celebración + bloqueo del evento + notificación al resto

## Sistema XP
- **Por GPS validado**: posición 1→10 XP, 2→9 XP, …, 10→1 XP; resto→1 XP. Tabla `clue_xp_awards` como fuente de verdad (también actúa de gate para `submit_clue_photo`).
- **Por completar hunt**: +500 XP al aprobar la última foto (en `approve_validation`).
- **Nivel**: `level = (xp ~/ 1000) + 1`. `xpForNextLevel = 1000` (constante por ahora).

## Seguridad
- Validación de victoria **exclusivamente en servidor** (nunca en cliente)
- Coordenadas GPS nunca expuestas al cliente (SECURITY DEFINER en RPCs)
- Foto solo enviable si GPS fue validado: `submit_clue_photo` comprueba entrada en `clue_xp_awards`
- Rate limiting **doble capa**: 30 s en cliente (`_lastCheckInAttempt` en MapScreen) + 25 s en servidor (`check_proximity` vía campo `last_proximity_check` en profiles)
- Detección de Mock Location (GPS falso) — **pendiente** (no implementada)
- `env.json` con credenciales incluido en assets (la anon key de Supabase es segura por diseño)

## Funcionalidades Planificadas (pendientes)
- `mobile_scanner ^5.1.0` ya en pubspec (comentado): escaneo QR en VictoryScreen
- Tutorial de onboarding (3 pasos con ilustraciones) antes del registro
- Términos y Condiciones con checkbox de exención de responsabilidad
- Detección de Mock Location con aviso al usuario
- Notificación al resto de jugadores cuando se completa un hunt
- Sistema de Escuadrón real (tabla `squads` + distribución de XP entre miembros)
- ~~Rate limiting server-side en `check_proximity`~~ ✅ implementado en `20261015000001`
- ~~Vista `leaderboard` como migración SQL~~ ✅ en `20261015000001`

## Notas Técnicas
- **Flutter Web**: no usar `dart:io` (crash en web). Usar `dart:async` para `TimeoutException`. Comprobar antes de añadir imports de plataforma.
- **Web debug sobre ngrok**: carga ~959 archivos JS separados, muy lento. Usar `--release` para pruebas móviles. Fallback de pantalla de carga en `web/index.html`: 30 s.
- **Supabase anon key en ngrok**: añadir `https://*.ngrok-free.app/**` en Supabase → Auth → URL Configuration → Allowed Origins.

## Config
- Supabase URL/key: `assets/env.json` (fallback) o `--dart-define` (preferido en CI)
- App name: `consola_tesoro`, versión 1.0.0+1
