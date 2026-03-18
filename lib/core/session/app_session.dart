import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class AppSession {
  AppSession._();

  static final ValueNotifier<Profile?> profile = ValueNotifier<Profile?>(null);
  static final ValueNotifier<bool> isAdmin = ValueNotifier<bool>(false);

  static void clear() {
    profile.value = null;
    isAdmin.value = false;
  }

  static Future<void> bootstrap(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) {
      clear();
      return;
    }
    await refreshProfile(client, userId: user.id);
  }

  static Future<void> refreshProfile(
    SupabaseClient client, {
    required String userId,
  }) async {
    final row = await client
        .from('profiles')
        .select('id, username, avatar_url, origin_region, xp, is_admin, wallet_balance')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      clear();
      return;
    }

    final p = Profile.fromMap(Map<String, dynamic>.from(row));
    profile.value = p;
    isAdmin.value = p.isAdmin;
  }
}

