import 'package:supabase_flutter/supabase_flutter.dart';

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

  // ── Asegura que hay una sesión activa (sign-in anónimo si no hay ninguna) ─
  Future<String> ensureUserId() async {
    final user = _client.auth.currentUser;
    if (user != null) return user.id;

    // Inicio de sesión anónimo (requiere habilitarlo en Supabase Dashboard:
    // Authentication → Providers → Anonymous Sign-ins → Enable)
    final res = await _client.auth.signInAnonymously();
    if (res.user == null) {
      throw Exception('No se pudo autenticar. '
          'Habilita "Anonymous Sign-ins" en tu proyecto de Supabase.');
    }
    return res.user!.id;
  }

  // ── Lista de hunts activos por región ────────────────────────────────────
  Future<List<Hunt>> listActiveHunts({required String region}) async {
    final rows = await _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info, region, status')
        .eq('status', 'active')
        .eq('region', region)
        .order('created_at');

    return rows.map((r) => Hunt.fromMap(r as Map<String, dynamic>)).toList();
  }

  // ── Conteo de hunts activos agrupados por región ─────────────────────────
  Future<Map<String, int>> countActiveHuntsByRegion() async {
    final rows = await _client.from('hunts').select('region').eq('status', 'active');
    final counts = <String, int>{};
    for (final row in (rows as List)) {
      final r = row['region'] as String?;
      if (r != null) counts[r] = (counts[r] ?? 0) + 1;
    }
    return counts;
  }

  // ── Hunts en borrador de una región (vista previa "Próximamente") ────────
  Future<List<Map<String, dynamic>>> listDraftHunts({
    required String region,
  }) async {
    final rows = await _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info, region, status')
        .eq('status', 'draft')
        .eq('region', region)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ── Hunts completados de una región (para mostrar como "antiguas") ───────
  Future<List<Map<String, dynamic>>> listCompletedHunts({
    required String region,
  }) async {
    final rows = await _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info, region, status, winner_id')
        .eq('status', 'completed')
        .eq('region', region)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ── Primer hunt activo ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getFirstActiveHunt() async {
    final rows = await _client
        .from('hunts')
        .select('id, title, description, difficulty, reward_info')
        .eq('status', 'active')
        .order('created_at')
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
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

  // ── Cuenta el total de pistas de un hunt (para indicador X / Y) ─────────────
  Future<int> countHuntClues(String huntId) async {
    final rows = await _client
        .from('clues')
        .select('id')
        .eq('hunt_id', huntId);
    return (rows as List).length;
  }

  // ── Distancia en metros al punto de la pista (sin revelar coordenadas) ───────
  Future<int> getClueDistance({
    required String clueId,
    required double lat,
    required double lng,
  }) async {
    final result = await _client.rpc('get_clue_distance', params: {
      'p_clue_id': clueId,
      'p_lat':     lat,
      'p_lng':     lng,
    });
    return (result as num).toInt();
  }

  // ── Envío seguro de foto (reemplaza INSERT directo del cliente) ───────────────
  Future<void> submitCluePhoto({
    required String clueId,
    required String photoUrl,
  }) async {
    await _client.rpc('submit_clue_photo', params: {
      'p_clue_id':   clueId,
      'p_photo_url': photoUrl,
    });
  }

  // ── Estado del progreso de una pista (para polling post-foto) ────────────────
  Future<String?> checkProgressStatus({
    required String userId,
    required String clueId,
  }) async {
    final rows = await _client
        .from('user_progress')
        .select('status')
        .eq('user_id', userId)
        .eq('clue_id', clueId)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return rows.first['status'] as String?;
  }

  // ── Otorgar XP al validar GPS de una pista (idempotente) ─────────────────────
  // Devuelve {xp_awarded, position, already_awarded}.
  Future<Map<String, dynamic>> awardProximityXp({
    required String clueId,
    required String userId,
  }) async {
    final result = await _client.rpc('award_proximity_xp', params: {
      'p_clue_id': clueId,
      'p_user_id': userId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  // ── Estado actual del hunt (status + winner_id) ──────────────────────────────
  // Usado en MapScreen para detectar si otro jugador ya ganó.
  Future<Map<String, dynamic>?> checkHuntStatus(String huntId) async {
    final row = await _client
        .from('hunts')
        .select('status, winner_id')
        .eq('id', huntId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  // ── IDs de hunts que el usuario terminó completamente en cliente ────────────
  // Un hunt "completado" tiene pistas 'validated' PERO NINGUNA 'pending'.
  // Si hay 'pending', el usuario aún está en curso (admin no aprobó la última
  // foto). Esta condición evita mover al bloque COMPLETADAS hunts en progreso.
  // Necesario para hunts cuyo status sigue 'active' en BD porque se completaron
  // antes de que approve_validation actualizara hunts.status automáticamente.
  Future<Set<String>> getUserFullyCompletedHuntIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('user_progress')
        .select('hunt_id, status')
        .eq('user_id', userId)
        .inFilter('status', ['validated', 'pending']);

    final byHunt = <String, Set<String>>{};
    for (final r in rows as List) {
      final hId = r['hunt_id'] as String;
      final st  = r['status']  as String;
      byHunt.putIfAbsent(hId, () => {}).add(st);
    }
    return byHunt.entries
        .where((e) =>
            e.value.contains('validated') && !e.value.contains('pending'))
        .map((e) => e.key)
        .toSet();
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
