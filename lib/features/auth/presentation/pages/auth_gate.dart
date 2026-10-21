import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/session/app_session.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/features/auth/presentation/pages/welcome_screen.dart';
import 'package:consola_tesoro/features/regions/presentation/pages/region_selection_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _sub;

  Session? _session;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _session = _client.auth.currentSession;
    _bootstrapFor(_session);

    _sub = _client.auth.onAuthStateChange.listen((state) {
      _session = state.session;
      _bootstrapFor(_session);
    });
  }

  Future<void> _bootstrapFor(Session? session) async {
    setState(() => _bootstrapping = true);
    try {
      if (session == null) {
        AppSession.clear();
      } else {
        await AppSession.refreshProfile(_client, userId: session.user.id);
      }
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const _AuthLoading();
    }
    return _session == null ? const WelcomeScreen() : const RegionSelectionScreen();
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    // On web the HTML splash screen handles the loading UI.
    // Return a matching background so the HTML fade-out is seamless.
    if (kIsWeb) {
      return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              Color(0xFF0B2A2C),
              AppColors.backgroundDark,
            ],
            stops: [0.0, 0.55, 1.0],
          ) : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.accentCyan.withOpacity(0.12),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.35)),
                ),
                child: const Icon(Icons.map_rounded,
                    color: AppColors.accentCyan, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Consola del Tesoro',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.accentCyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

