import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/models/profile.dart';
import 'package:consola_tesoro/core/session/app_session.dart';

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository(this._client);

  Future<Profile> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('No hay sesión activa.');
    await AppSession.refreshProfile(_client, userId: user.id);
    final p = AppSession.profile.value;
    if (p == null) {
      throw const PostgrestException(message: 'No se pudo cargar el perfil.');
    }
    return p;
  }

  Future<Profile> updateMyProfile({
    required String username,
    required String? avatarUrl,
    required String? originRegion,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('No hay sesión activa.');

    final u = username.trim();
    if (u.isEmpty) {
      throw const PostgrestException(message: 'El nombre de usuario no puede estar vacío.');
    }

    await _client.from('profiles').update({
      'username': u,
      'avatar_url': (avatarUrl ?? '').trim().isEmpty ? null : avatarUrl!.trim(),
      'origin_region': (originRegion ?? '').trim().isEmpty ? null : originRegion!.trim(),
    }).eq('id', user.id);

    await AppSession.refreshProfile(_client, userId: user.id);
    final p = AppSession.profile.value;
    if (p == null) {
      throw const PostgrestException(message: 'Perfil actualizado, pero no se pudo refrescar.');
    }
    return p;
  }
}

