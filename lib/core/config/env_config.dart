import 'dart:convert';

import 'package:flutter/services.dart';

class EnvConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const EnvConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  static const String _assetPath = 'assets/env.json';

  static Future<EnvConfig> load() async {
    final urlFromDefine = const String.fromEnvironment('SUPABASE_URL').trim();
    final keyFromDefine =
        const String.fromEnvironment('SUPABASE_ANON_KEY').trim();

    if (urlFromDefine.isNotEmpty && keyFromDefine.isNotEmpty) {
      return EnvConfig(
        supabaseUrl: urlFromDefine,
        supabaseAnonKey: keyFromDefine,
      );
    }

    final raw = await rootBundle.loadString(_assetPath);
    final m = jsonDecode(raw) as Map<String, dynamic>;

    final url = (m['SUPABASE_URL'] as String?)?.trim() ?? '';
    final key = (m['SUPABASE_ANON_KEY'] as String?)?.trim() ?? '';

    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Faltan credenciales de Supabase. Define SUPABASE_URL/SUPABASE_ANON_KEY '
        'con --dart-define o completa $_assetPath.',
      );
    }

    return EnvConfig(supabaseUrl: url, supabaseAnonKey: key);
  }
}

