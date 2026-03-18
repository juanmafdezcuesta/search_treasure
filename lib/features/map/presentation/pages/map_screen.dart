import 'dart:math' show pi, sin;

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/core/session/app_session.dart';
import 'package:consola_tesoro/data/datasources/supabase/hunt_datasource.dart';
import 'package:consola_tesoro/features/admin/presentation/pages/admin_screen.dart';
import 'package:consola_tesoro/features/ranking/presentation/pages/ranking_screen.dart';
import 'package:consola_tesoro/features/profile/presentation/pages/profile_screen.dart';
import '../widgets/clue_bottom_panel.dart';

class MapScreen extends StatefulWidget {
  final String? huntId;
  final String? huntTitle;

  const MapScreen({
    super.key,
    this.huntId,
    this.huntTitle,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _mapController = MapController();
  final _supabase      = Supabase.instance.client;
  final _imagePicker   = ImagePicker();
  late final HuntDatasource _huntDS;

  // ── Estado de datos ───────────────────────────────────────────────────────
  String?     _huntId;
  String?     _huntTitle;
  ActiveClue? _activeClue;
  String?     _userId;
  bool        _dataLoading = true;
  String?     _dataError;
  bool        _needsJoin = false;
  String?     _joinError;
  bool        _victory = false;

  RealtimeChannel? _progressChannel;
  String? _subUserId;
  String? _subHuntId;

  // ── Estado del jugador ────────────────────────────────────────────────────
  LatLng? _playerPosition;
  bool    _locationLoading = false;

  // ── Estado del panel de acción ────────────────────────────────────────────
  ClueActionState _actionState = ClueActionState.idle;

  // ── Animaciones ───────────────────────────────────────────────────────────
  late final AnimationController _shakeController;
  late final Animation<double>   _shakeAnimation;
  late final ConfettiController  _confettiController;

  // Madrid como fallback hasta obtener GPS
  static const LatLng _defaultCenter = LatLng(40.4168, -3.7038);
  static const String _tileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  @override
  void initState() {
    super.initState();
    _huntDS = HuntDatasource(_supabase);

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeController, curve: _ShakeCurve()));

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _loadData();
    _initLocation();
  }

  @override
  void dispose() {
    _progressChannel?.unsubscribe();
    _shakeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _ensureProgressSubscription({required String userId, required String huntId}) {
    if (_subUserId == userId && _subHuntId == huntId && _progressChannel != null) return;

    _progressChannel?.unsubscribe();
    _subUserId = userId;
    _subHuntId = huntId;

    _progressChannel = _supabase
        .channel('progress:$userId:$huntId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_progress',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Recarga al validar/insertar la siguiente pista
            if (!mounted) return;
            _loadData();
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Carga: autenticación → hunt → pista activa
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() { _dataLoading = true; _dataError = null; });

    try {
      // 1. Asegurar usuario autenticado
      _userId = await _huntDS.ensureUserId();

      // 2. Hunt seleccionado (o primer activo como fallback)
      final selectedHuntId = widget.huntId;
      final hunt = selectedHuntId != null && selectedHuntId.trim().isNotEmpty
          ? await _huntDS.getHuntById(selectedHuntId.trim())
          : await _huntDS.getFirstActiveHunt();

      if (hunt == null) {
        setState(() {
          _dataError   = 'No hay ningún tesoro activo en este momento.\n'
                         'Pide al Maestro que active un Hunt desde el panel.';
          _dataLoading = false;
          _needsJoin   = false;
        });
        return;
      }

      _huntId    = hunt.id;
      _huntTitle = hunt.title;

      _victory = false;

      // 3. Pista activa para este jugador
      final clue = await _huntDS.getActiveClue(_userId!, _huntId!);
      if (clue == null) {
        // Diferenciar: "aún no empezaste" vs "completaste todo"
        final userId = _userId;
        final huntId = _huntId;
        if (userId == null || huntId == null) {
          setState(() {
            _dataError = 'Error de sesión: faltan datos para cargar el progreso.';
            _dataLoading = false;
            _needsJoin = false;
          });
          return;
        }

        final count = await _supabase
            .from('user_progress')
            .select('id')
            .eq('user_id', userId)
            .eq('hunt_id', huntId)
            .count(CountOption.exact);

        final hasProgress = (count.count ?? 0) > 0;
        setState(() {
          _needsJoin = !hasProgress;
          _dataError = hasProgress
              ? '¡Ya has completado todas las pistas de este tesoro!'
              : null;
          _dataLoading = false;
          _victory = hasProgress;
        });
        return;
      }

      final userId = _userId!;
      final huntId = _huntId!;
      _ensureProgressSubscription(userId: userId, huntId: huntId);

      setState(() {
        _activeClue  = clue;
        _dataLoading = false;
        _actionState = ClueActionState.idle;
        _needsJoin   = false;
        _victory     = false;
      });
    } catch (e) {
      setState(() {
        final msg = e.toString();
        _dataError = msg.contains('No hay sesión activa')
            ? 'Necesitas iniciar sesión para jugar.\n'
              'Vuelve atrás y entra o juega como invitado.'
            : msg;
        _dataLoading = false;
        _needsJoin   = false;
      });
    }
  }

  Future<void> _joinHunt() async {
    if (_userId == null) return;
    setState(() { _dataLoading = true; _dataError = null; _joinError = null; });
    try {
      final result = await _supabase.rpc('join_hunt', params: {
        'p_hunt_title': 'El Tesoro de Avilés',
      }) as Map<String, dynamic>;

      final success = result['success'] as bool? ?? false;
      if (!success) {
        final msg =
            (result['message'] as String?) ?? 'No se pudo iniciar.';
        if (!mounted) return;
        setState(() {
          _joinError = msg;
          _dataLoading = false;
          _needsJoin = true;
        });
        _showSnack(msg, color: AppColors.accentCoral);
        return;
      }
      // Forzar recarga inmediata de hunt + pista activa.
      await _loadData();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _joinError = e.message;
        _dataLoading = false;
        _needsJoin = true;
      });
      _showSnack(e.message, color: AppColors.error);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joinError = e.toString();
        _dataLoading = false;
        _needsJoin = true;
      });
      _showSnack('Error: $e', color: AppColors.error);
    }
  }

  Future<void> _resetMyProgress() async {
    if (_huntId == null) return;
    try {
      await _supabase.rpc('reset_my_progress', params: {
        'p_hunt_id': _huntId,
      });
      if (!mounted) return;
      _showSnack('Progreso reseteado. Ya puedes empezar de nuevo.',
          color: AppColors.accentGold);
      await _loadData();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showSnack('Error: ${e.message}', color: AppColors.error);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', color: AppColors.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Geolocalización
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    setState(() => _locationLoading = true);
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _locationLoading = false);
      _showSnack('Necesitamos acceso a tu ubicación para jugar.',
          color: AppColors.accentCoral);
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() {
      _playerPosition  = LatLng(pos.latitude, pos.longitude);
      _locationLoading = false;
    });
    _mapController.move(_playerPosition!, 15.0);
  }

  Future<void> _centerOnPlayer() async {
    if (_playerPosition != null) {
      _mapController.move(_playerPosition!, 16.0);
    } else {
      await _initLocation();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 1: Validar GPS → Supabase RPC check_proximity
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onCheckIn() async {
    if (_playerPosition == null) {
      _showSnack('Esperando señal GPS...', color: AppColors.accentCoral);
      return;
    }
    if (_activeClue == null) return;

    setState(() => _actionState = ClueActionState.checkingGps);
    HapticFeedback.mediumImpact();

    bool isNear = false;
    try {
      final result = await _supabase.rpc('check_proximity', params: {
        'p_clue_id': _activeClue!.clueId,
        'p_lat':     _playerPosition!.latitude,
        'p_lng':     _playerPosition!.longitude,
      });
      isNear = result as bool;
    } on PostgrestException catch (e) {
      if (kDebugMode) debugPrint('[GPS] ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('[GPS] $e');
    }

    if (!mounted) return;
    if (isNear) {
      setState(() => _actionState = ClueActionState.gpsValidated);
      HapticFeedback.heavyImpact();
    } else {
      _onGpsFail();
    }
  }

  void _onGpsFail() {
    setState(() => _actionState = ClueActionState.tooFar);
    _shakeController.forward(from: 0);
    HapticFeedback.vibrate();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _actionState == ClueActionState.tooFar) {
        setState(() => _actionState = ClueActionState.idle);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 2: Cámara → Storage → user_progress (pending)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onTakePhoto() async {
    final activeClue = _activeClue;
    final userId = _userId;
    final huntId = _huntId;
    if (activeClue == null || userId == null || huntId == null) return;

    final XFile? photo = await _imagePicker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 80,
      maxWidth:     1280,
    );
    if (photo == null || !mounted) return;

    setState(() => _actionState = ClueActionState.uploading);

    try {
      final timestamp   = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$userId/${timestamp}_${activeClue.clueId}.jpg';
      final imageBytes  = await photo.readAsBytes();

      // Subir foto al bucket validation_photos
      await _supabase.storage
          .from('validation_photos')
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: false),
          );

      // Crear registro en user_progress con status 'pending'
      await _supabase.from('user_progress').insert({
        'user_id':  userId,
        'hunt_id':  huntId,
        'clue_id':  activeClue.clueId,
        'status':   'pending',
        'photo_url': storagePath,
      });

      if (!mounted) return;
      setState(() => _actionState = ClueActionState.submitted);
      _confettiController.play();
    } on StorageException catch (e) {
      if (!mounted) return;
      setState(() => _actionState = ClueActionState.gpsValidated);
      _showSnack('Error al subir la foto: ${e.message}', color: AppColors.error);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _actionState = ClueActionState.gpsValidated);
      _showSnack('Error al registrar progreso: ${e.message}',
          color: AppColors.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Avanza a la siguiente pista (llamado desde fuera o tras aprobación)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadNextClue() async {
    if (_userId == null || _huntId == null) return;
    final next = await _huntDS.getActiveClue(_userId!, _huntId!);
    if (!mounted) return;
    setState(() {
      _activeClue  = next;
      _actionState = next == null
          ? ClueActionState.idle   // victoria — el server ya cerró el hunt
          : ClueActionState.idle;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUG
  // ─────────────────────────────────────────────────────────────────────────
  void _debugSkipToGpsOk() {
    if (_playerPosition == null) {
      setState(() => _playerPosition = _defaultCenter);
    }
    setState(() => _actionState = ClueActionState.gpsValidated);
    _showSnack('DEBUG: GPS simulado ✓', color: AppColors.accentGold);
  }

  void _showSnack(String msg, {Color color = AppColors.accentCyan}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight    = screenHeight * 0.80;
    final panelHeight  = screenHeight * 0.20;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _huntTitle ?? 'Consola del Tesoro',
          style: const TextStyle(color: AppColors.accentCyan,
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: AppColors.textPrimary),
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimary),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await _supabase.auth.signOut();
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSession.isAdmin,
            builder: (_, isAdmin, __) => IconButton(
              icon: Icon(Icons.restart_alt_rounded,
                  color: isAdmin ? AppColors.accentGold : AppColors.textSecondary),
              tooltip: isAdmin ? 'Resetear mi progreso' : 'Solo administradores',
              onPressed: (!isAdmin || _huntId == null) ? null : _resetMyProgress,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSession.isAdmin,
            builder: (_, isAdmin, __) => IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded,
                  color: AppColors.textPrimary),
              tooltip: isAdmin ? 'Panel del Maestro' : 'Solo administradores',
              onPressed: (!isAdmin || _huntId == null)
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AdminScreen(huntId: _huntId!)),
                      ),
            ),
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: panelHeight + 12),
        child: FloatingActionButton(
          onPressed: _centerOnPlayer,
          backgroundColor: AppColors.accentCyan,
          foregroundColor: AppColors.backgroundDark,
          tooltip: 'Centrar mi ubicación',
          child: _locationLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.backgroundDark))
              : const Icon(Icons.my_location_rounded, size: 26),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: 380.ms,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _needsJoin
                ? _JoinHuntEmptyState(
                    key: const ValueKey('join'),
                    huntTitle: _huntTitle ?? 'El Tesoro de Avilés',
                    onStart: _joinHunt,
                    loading: _dataLoading,
                    errorMessage: _joinError,
                  ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.06)
                : _victory && _huntId != null
                    ? _VictoryState(
                        key: const ValueKey('victory'),
                        huntTitle: _huntTitle ?? 'Tesoro completado',
                        onRanking: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RankingScreen(),
                          ),
                        ),
                      ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.06)
                : Column(
                    key: const ValueKey('map'),
                    children: [
                      // ── 80%: Mapa ──────────────────────────────────────
                      SizedBox(
                        height: mapHeight,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:   _defaultCenter,
                            initialZoom:     14.0,
                            minZoom: 10.0,   maxZoom: 19.0,
                            backgroundColor: AppColors.backgroundDark,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: _tileUrl,
                              subdomains:  const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.tesoro.app',
                              retinaMode: true,
                            ),
                            if (_playerPosition != null)
                              MarkerLayer(markers: [
                                Marker(
                                  point: _playerPosition!,
                                  width: 40, height: 40,
                                  child: const _PlayerMarker(),
                                ),
                              ]),
                            RichAttributionWidget(attributions: [
                              TextSourceAttribution(
                                  '© OpenStreetMap contributors © CARTO'),
                            ]),
                          ],
                        ),
                      ),

                      // ── 20%: Panel de pista ────────────────────────────
                      SizedBox(
                        height: panelHeight,
                        child: _dataLoading
                            ? const _LoadingPanel()
                            : _dataError != null
                                ? _ErrorPanel(
                                    message:  _dataError!,
                                    onRetry:  _loadData,
                                  )
                                : AnimatedBuilder(
                                    animation: _shakeAnimation,
                                    builder: (context, child) => Transform.translate(
                                      offset: Offset(_shakeAnimation.value * 14, 0),
                                      child: child,
                                    ),
                                    child: ClueBottomPanel(
                                      riddleText:  _activeClue!.riddleText,
                                      actionState: _actionState,
                                      onCheckIn:   _onCheckIn,
                                      onTakePhoto: _onTakePhoto,
                                    ).animate()
                                        .slideY(begin: 0.3, duration: 400.ms,
                                                curve: Curves.easeOut)
                                        .fadeIn(duration: 300.ms),
                                  ),
                      ),
                    ],
                  ),
          ),

          // ── Confeti ─────────────────────────────────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController:  _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles:   40,
              gravity:             0.15,
              colors: const [
                AppColors.accentCyan,  AppColors.accentCoral,
                AppColors.accentGold,  AppColors.success, Colors.white,
              ],
            ),
          ),

          // ── Botón DEBUG ─────────────────────────────────────────────────
          if (kDebugMode)
            Positioned(
              bottom: panelHeight + 16,
              left:   16,
              child: Tooltip(
                message: 'DEBUG: Simular GPS ok',
                child: FloatingActionButton.small(
                  heroTag:         'debug_fab',
                  onPressed:       _debugSkipToGpsOk,
                  backgroundColor: AppColors.accentGold.withOpacity(0.85),
                  foregroundColor: AppColors.backgroundDark,
                  child: const Icon(Icons.bug_report_rounded, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares del panel
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.cardDark,
    child: const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accentCyan)),
          SizedBox(width: 12),
          Text('Cargando pista...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.cardDark,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: AppColors.accentCoral, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _JoinHuntEmptyState extends StatelessWidget {
  final String huntTitle;
  final VoidCallback onStart;
  final bool loading;
  final String? errorMessage;
  const _JoinHuntEmptyState({
    super.key,
    required this.huntTitle,
    required this.onStart,
    required this.loading,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.accentGold.withOpacity(0.12),
                          border: Border.all(
                              color: AppColors.accentGold.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: AppColors.accentGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          huntTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '¡Bienvenido!',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 30),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aún no te has unido a esta búsqueda.\nPulsa el botón para empezar con la primera pista.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  if (errorMessage != null && errorMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accentCoral.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accentCoral.withOpacity(0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.accentCoral, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: loading ? null : onStart,
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.backgroundDark,
                            ),
                          )
                        : const Text('¡Empezar la Búsqueda del Tesoro!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VictoryState extends StatelessWidget {
  final String huntTitle;
  final VoidCallback onRanking;
  const _VictoryState({
    super.key,
    required this.huntTitle,
    required this.onRanking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.accentGold.withOpacity(0.12),
                          border: Border.all(
                              color: AppColors.accentGold.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: AppColors.accentGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          huntTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '¡Tesoro completado!',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Has terminado todas las pistas disponibles.\n¿Quieres ver cómo va el ranking?',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: onRanking,
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: const Text('Ver ranking'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ShakeCurve extends Curve {
  @override
  double transformInternal(double t) => sin(t * pi * 5) * (1 - t);
}

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentCyan.withOpacity(0.2),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2),
                   duration: 1200.ms, curve: Curves.easeInOut)
            .then()
            .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8),
                   duration: 1200.ms, curve: Curves.easeInOut),
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentCyan,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.6), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}
