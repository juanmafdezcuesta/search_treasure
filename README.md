# La Consola del Tesoro de Avilés

App móvil (Flutter) de **búsqueda del tesoro gamificada** basada en **geolocalización**, con backend en **Supabase**.

## Qué hace

- **Jugador**: abre el mapa, recibe un acertijo (pista), valida su cercanía por GPS (RPC) y sube una foto como prueba.
- **Administrador / Maestro**: revisa las pruebas pendientes y **aprueba o rechaza** validaciones. Si se aprueba la última pista, se marca el hunt como completado y se asigna ganador.

## Stack

- **Flutter** (Dart)
- **Supabase** (Auth, Postgres + RLS, Storage, RPC)
- **Mapa**: `flutter_map` (tiles)
- **GPS**: `geolocator`
- **Cámara**: `image_picker`

## Configuración de Supabase (credenciales)

La app inicializa Supabase en `lib/main.dart` y necesita `SUPABASE_URL` y `SUPABASE_ANON_KEY`.

### Opción recomendada (Windows/macOS/Linux): `--dart-define-from-file`

Rellena `.env.json` (en la raíz del proyecto) con:

```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "TU_ANON_KEY"
}
```

Ejecuta:

```bash
flutter pub get
flutter run --dart-define-from-file=.env.json
```

### Opción alternativa: `assets/env.json` (fallback)

Si no pasas `--dart-define*`, la app intenta leer `assets/env.json`. Puedes copiar tu `.env.json` a `assets/env.json` si te conviene para desarrollo local.

> Nota: cualquier valor que empaquetes (en assets o `--dart-define`) puede terminar en el bundle de la app. Trata las keys con cuidado.

## Base de datos (migraciones)

El esquema y las funciones viven en `supabase/migrations/`:

- **`profiles`**: perfil del usuario (incluye `is_admin`)
- **`hunts`**: eventos/búsquedas del tesoro
- **`clues`**: pistas con `location` (PostGIS) y radio de validación
- **`user_progress`**: progreso por pista (pendiente/validada) + foto
- RPC principales:
  - `check_proximity` (valida cercanía sin exponer ubicación secreta)
  - `get_active_clue` (devuelve la pista activa sin exponer `location`)
  - `get_pending_validations` / `approve_validation` / `reject_validation` (panel de Maestro)

## Estructura rápida

- `lib/main.dart`: arranque, carga de credenciales y bootstrap de sesión
- `lib/features/map/...`: experiencia del jugador
- `lib/features/admin/...`: panel de Maestro
- `lib/data/datasources/supabase/`: acceso a Supabase (queries/RPC)

