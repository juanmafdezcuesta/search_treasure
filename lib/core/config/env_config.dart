class EnvConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const EnvConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  static EnvConfig load() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Variables de entorno no configuradas. '
        'Compila con --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
        'o usa --dart-define-from-file=env.json',
      );
    }

    return const EnvConfig(supabaseUrl: url, supabaseAnonKey: key);
  }
}
