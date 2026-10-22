import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/config/env_config.dart';
import 'core/session/app_session.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = EnvConfig.load();
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSession.themeMode,
      builder: (_, mode, __) => MaterialApp(
        title:                    'Búsqueda del Tesoro',
        debugShowCheckedModeBanner: false,
        theme:                    AppTheme.light,
        darkTheme:                AppTheme.dark,
        themeMode:                mode,
        locale:                   const Locale('es', 'ES'),
        localizationsDelegates:   const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales:         const [Locale('es', 'ES')],
        home:                     const AuthGate(),
      ),
    );
  }
}
