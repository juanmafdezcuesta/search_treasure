import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/config/env_config.dart';
import 'core/session/app_session.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = await EnvConfig.load();
  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

  // Si hay una sesión persistida, verificamos inmediatamente si es admin.
  await AppSession.bootstrap(Supabase.instance.client);

  runApp(const ConsolaTesoro());
}

class ConsolaTesoro extends StatelessWidget {
  const ConsolaTesoro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'Consola del Tesoro',
      debugShowCheckedModeBanner: false,
      theme:        AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
