import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/session/app_session.dart';
import 'package:consola_tesoro/features/auth/presentation/pages/login_screen.dart';
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
    return _session == null ? const LoginScreen() : const RegionSelectionScreen();
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}

