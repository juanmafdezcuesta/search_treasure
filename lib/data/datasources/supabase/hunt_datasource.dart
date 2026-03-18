import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:consola_tesoro/core/session/app_session.dart';
import 'package:consola_tesoro/core/models/hunt.dart';

/// Modelo ligero con los datos de una pista que la UI necesita mostrar.
/// NO incluye `location` (protegido en servidor por SECURITY DEFINER).
class ActiveClue {
  final String clueId;
  final String huntId;
  final int    stepOrder;
  final String riddleText;
  final int    radiusMeters;

  const ActiveClue({
    required this.clueId,
    required this.huntId,
    required this.stepOrder,
    required this.riddleText,
    required this.radiusMeters,
  });

  factory ActiveClue.fromMap(String huntId, Map<String, dynamic> m) =>
      ActiveClue(
        clueId:       m['clue_id']       as String,
        huntId:       huntId,
        stepOrder:    (m['step_order']   as num).toInt(),
        riddleText:   m['riddle_text']   as String,
        radiusMeters: (m['radius_meters'] as num).toInt(),
      );
}

class HuntDatasource {
  final SupabaseClient _client;
  HuntDatasource(this._client);

  // ── Asegura que hay una sesión activa ─────────────────────────────────────
  Future<String> ensureUserId() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      // Asegura que la app conoce si este usuario es admin.
      await AppSession.refreshProfile(_client, userId: user.id);
      return user.id;
    }

    throw const AuthException('No hay sesión activa.');
  }

  // ── Hunts activos (opcional: filtrado por región) ─────────────────────────
  Future<List<Hunt>> listActiveHunts({String? region}) async {
    final q = _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info, status, region')
        .eq('status', 'active');

    final r = region?.trim();
    if (r != null && r.isNotEmpty) {
      q.eq('region', r);
    }

    final rows = await q.order('created_at');
    return List<Map<String, dynamic>>.from(rows)
        .map((m) => Hunt.fromMap(m))
        .toList();
  }

  // ── Primer hunt activo (compatibilidad) ───────────────────────────────────
  Future<Hunt?> getFirstActiveHunt() async {
    final rows = await _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info, status, region')
        .eq('status', 'active')
        .order('created_at')
        .limit(1);

    if (rows.isEmpty) return null;
    return Hunt.fromMap(Map<String, dynamic>.from(rows.first));
  }

  // ── Hunt por id (debe ser accesible por RLS) ──────────────────────────────
  Future<Hunt?> getHuntById(String huntId) async {
    final row = await _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info, status, region')
        .eq('id', huntId)
        .maybeSingle();

    if (row == null) return null;
    return Hunt.fromMap(Map<String, dynamic>.from(row));
  }

  // ── Pista activa para este usuario (vía RPC get_active_clue) ─────────────
  // Devuelve null si el jugador ya completó todas las pistas del hunt.
  Future<ActiveClue?> getActiveClue(String userId, String huntId) async {
    final rows = await _client.rpc('get_active_clue', params: {
      'p_user_id': userId,
      'p_hunt_id': huntId,
    }) as List<dynamic>;

    if (rows.isEmpty) return null;
    return ActiveClue.fromMap(huntId, rows.first as Map<String, dynamic>);
  }

  // ── Validaciones ya aprobadas (para la vista de ganadores en AdminScreen) ─
  Future<List<Map<String, dynamic>>> getValidatedProgress(String huntId) async {
    final rows = await _client
        .from('user_progress')
        .select('''
          id,
          validated_at,
          photo_url,
          profiles ( username, avatar_url ),
          clues ( step_order, riddle_text )
        ''')
        .eq('hunt_id', huntId)
        .eq('status', 'validated')
        .order('validated_at');

    return List<Map<String, dynamic>>.from(rows);
  }
}
