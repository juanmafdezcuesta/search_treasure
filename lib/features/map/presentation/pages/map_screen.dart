import 'dart:async';
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
import 'package:consola_tesoro/data/datasources/supabase/hunt_datasource.dart';
import 'package:consola_tesoro/features/admin/presentation/pages/admin_screen.dart';
import '../widgets/clue_bottom_panel.dart';

class MapScreen extends StatefulWidget {
  final String  huntId;
  final String  huntTitle;
  final String? region;
  const MapScreen({super.key, required this.huntId, required this.huntTitle, this.region});

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

  // ── Estado del jugador ────────────────────────────────────────────────────
  LatLng? _playerPosition;
  bool    _locationLoading = false;

  // ── Estado del panel de acción ────────────────────────────────────────────
  ClueActionState _actionState = ClueActionState.idle;

  // ── Progreso y distancia ──────────────────────────────────────────────────
  int  _totalSteps    = 1;
  int? _distanceMeters;

  // ── Polling post-foto ─────────────────────────────────────────────────────
  Timer? _pollTimer;

  // ── Rate limiting check-in ────────────────────────────────────────────────
  DateTime? _lastCheckInAttempt;
  static const _checkInCooldown = Duration(seconds: 30);

  // ── Estado: otro jugador ya ganó ─────────────────────────────────────────
  bool _huntWonByOtherShown = false;

  // ── Animaciones ───────────────────────────────────────────────────────────
  late final AnimationController _shakeController;
  late final Animation<double>   _shakeAnimation;
  late final ConfettiController  _confettiController;

  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Centro inicial basado en la región del hunt (fallback: centro de España)
  late final LatLng _mapInitialCenter;

  static const Map<String, LatLng> _regionCenters = {
    'Andalucía':           LatLng(37.5443, -4.7278),
    'Aragón':              LatLng(41.5976, -0.9057),
    'Asturias':            LatLng(43.3614, -5.8593),
    'Illes Balears':       LatLng(39.5696,  2.6502),
    'Canarias':            LatLng(28.2916, -16.6291),
    'Cantabria':           LatLng(43.1828, -3.9878),
    'Castilla-La Mancha':  LatLng(39.8628, -4.0273),
    'Castilla y León':     LatLng(41.6539, -4.7246),
    'Cataluña':            LatLng(41.5912,  1.5209),
    'C. Valenciana':       LatLng(39.4840, -0.7533),
    'Extremadura':         LatLng(39.4952, -6.0679),
    'Galicia':             LatLng(42.5751, -8.1339),
    'La Rioja':            LatLng(42.2871, -2.5396),
    'Comunidad de Madrid': LatLng(40.4168, -3.7038),
    'Región de Murcia':    LatLng(37.9922, -1.1307),
    'Navarra':             LatLng(42.6953, -1.6761),
    'País Vasco':          LatLng(43.2630, -2.9349),
  };

  @override
  void initState() {
    super.initState();
    _huntDS = HuntDatasource(_supabase);

    _mapInitialCenter = _regionCenters[widget.region] ?? const LatLng(40.4168, -3.7038);

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
    _stopPolling();
    _shakeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Carga: autenticación → hunt → pista activa
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() { _dataLoading = true; _dataError = null; });

    try {
      // 1. Asegurar usuario autenticado
      _userId = await _huntDS.ensureUserId();

      _huntId    = widget.huntId;
      _huntTitle = widget.huntTitle;

      // 2. Pista activa + total de pistas (en paralelo)
      final clue  = await _huntDS.getActiveClue(_userId!, _huntId!);
      final total = await _huntDS.countHuntClues(_huntId!);

      // 3. Comprobar si ya hay una foto pendiente de aprobación para esta pista
      ClueActionState initialState = ClueActionState.idle;
      if (clue != null) {
        final existingStatus = await _huntDS.checkProgressStatus(
          userId: _userId!,
          clueId: clue.clueId,
        );
        if (existingStatus == 'pending') {
          initialState = ClueActionState.submitted;
        }
      }

      setState(() {
        _activeClue  = clue;
        _totalSteps  = total > 0 ? total : 1;
        _dataLoading = false;
        _actionState = initialState;
      });

      // Si había envío pendiente, retomar el polling
      if (initialState == ClueActionState.submitted) {
        _startPolling();
      }

      // Comprobar si el hunt ya fue ganado por otro jugador
      await _checkIfHuntWonByOther();
    } catch (e) {
      setState(() {
        _dataError   = e.toString();
        _dataLoading = false;
      });
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

    // Rate limiting: mínimo 30 s entre intentos
    final now = DateTime.now();
    if (_lastCheckInAttempt != null &&
        now.difference(_lastCheckInAttempt!) < _checkInCooldown) {
      final secs = (_checkInCooldown - now.difference(_lastCheckInAttempt!))
          .inSeconds;
      _showSnack('Espera $secs s antes de reintentar.',
          color: AppColors.textSecondary);
      return;
    }
    _lastCheckInAttempt = now;

    setState(() {
      _actionState     = ClueActionState.checkingGps;
      _distanceMeters  = null;
    });
    HapticFeedback.mediumImpact();

    bool isNear = false;
    try {
      final result = await _supabase.rpc('check_proximity', params: {
        'p_clue_id': _activeClue!.clueId,
        'p_lat':     _playerPosition!.latitude,
        'p_lng':     _playerPosition!.longitude,
      }).timeout(const Duration(seconds: 10));
      isNear = result as bool;
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _actionState = ClueActionState.idle);
      _showSnack('Sin respuesta del servidor. Comprueba tu conexión.',
          color: AppColors.error);
      return;
    } on PostgrestException catch (e) {
      if (kDebugMode) debugPrint('[GPS] ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('[GPS] $e');
    }

    if (!mounted) return;
    if (isNear) {
      setState(() => _actionState = ClueActionState.gpsValidated);
      HapticFeedback.heavyImpact();
      _awardClueXp();
    } else {
      _onGpsFail();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // XP inmediato por GPS OK
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _awardClueXp() async {
    if (_activeClue == null || _userId == null) return;
    try {
      final result = await _huntDS.awardProximityXp(
        clueId: _activeClue!.clueId,
        userId: _userId!,
      );
      if (!mounted || result['already_awarded'] == true) return;
      final xp  = (result['xp_awarded'] as num).toInt();
      final pos = (result['position']   as num).toInt();
      _showXpToast(xp, pos);
    } catch (e) {
      if (kDebugMode) debugPrint('[XP] $e');
    }
  }

  void _showXpToast(int xp, int pos) {
    final String posLabel;
    if (pos == 1)       posLabel = '¡1º en llegar! 🥇';
    else if (pos == 2)  posLabel = '2º en llegar 🥈';
    else if (pos == 3)  posLabel = '3º en llegar 🥉';
    else if (pos <= 10) posLabel = 'Posición #$pos';
    else                posLabel = '';

    final msg = posLabel.isNotEmpty ? '$posLabel  ·  +$xp XP' : '+$xp XP';
    _showSnack(msg, color: AppColors.accentGold);
  }

  void _onGpsFail() {
    setState(() => _actionState = ClueActionState.tooFar);
    _shakeController.forward(from: 0);
    HapticFeedback.vibrate();
    _fetchDistance();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _actionState == ClueActionState.tooFar) {
        setState(() => _actionState = ClueActionState.idle);
      }
    });
  }

  Future<void> _fetchDistance() async {
    if (_playerPosition == null || _activeClue == null) return;
    try {
      final d = await _huntDS.getClueDistance(
        clueId: _activeClue!.clueId,
        lat:    _playerPosition!.latitude,
        lng:    _playerPosition!.longitude,
      );
      if (mounted) setState(() => _distanceMeters = d);
    } catch (e) {
      if (kDebugMode) debugPrint('[DIST] $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 2: Cámara → Storage → user_progress (pending)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onTakePhoto() async {
    if (_activeClue == null || _userId == null) return;

    final XFile? photo = await _imagePicker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 80,
      maxWidth:     1280,
    );
    if (photo == null || !mounted) return;

    setState(() => _actionState = ClueActionState.uploading);

    try {
      final timestamp   = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$_userId/${timestamp}_${_activeClue!.clueId}.jpg';
      final imageBytes  = await photo.readAsBytes();

      // 1. Subir foto con timeout de 30 s
      await _supabase.storage
          .from('validation_photos')
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: false),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Tiempo de subida agotado'),
          );

      // 2. Registrar progreso via RPC seguro (verifica que GPS fue validado)
      await _huntDS.submitCluePhoto(
        clueId:   _activeClue!.clueId,
        photoUrl: storagePath,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _actionState = ClueActionState.submitted);
      // Confeti se activa cuando el admin aprueba la foto (ver _checkApproval)
      _startPolling();
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _actionState = ClueActionState.gpsValidated);
      _showSnack('Tiempo de espera agotado. Comprueba tu conexión.',
          color: AppColors.error);
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
  // Polling: comprobar cada 5 s si el admin aprobó la foto
  // ─────────────────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkApproval(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkApproval() async {
    if (_activeClue == null || _userId == null) return;
    try {
      // Comprobar si otro jugador ganó mientras esperamos la aprobación
      await _checkIfHuntWonByOther();

      final status = await _huntDS.checkProgressStatus(
        userId: _userId!,
        clueId: _activeClue!.clueId,
      );
      if (!mounted || status != 'validated') return;

      _stopPolling();
      _confettiController.play();
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await _loadNextClue();
    } catch (e) {
      if (kDebugMode) debugPrint('[POLL] $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Avanza a la siguiente pista tras aprobación del admin
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadNextClue() async {
    if (_userId == null || _huntId == null) return;
    final next = await _huntDS.getActiveClue(_userId!, _huntId!);
    if (!mounted) return;
    setState(() {
      _activeClue     = next;
      _distanceMeters = null;
      _actionState    = ClueActionState.idle;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detectar si otro jugador ya ganó este hunt
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _checkIfHuntWonByOther() async {
    if (_huntWonByOtherShown || _huntId == null || _userId == null) return;
    try {
      final status = await _huntDS.checkHuntStatus(_huntId!);
      if (!mounted || status == null) return;
      final winner = status['winner_id'] as String?;
      if (status['status'] == 'completed' &&
          winner != null &&
          winner != _userId) {
        _huntWonByOtherShown = true;
        _showHuntWonByOtherDialog();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HUNT_STATUS] $e');
    }
  }

  void _showHuntWonByOtherDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.accentCoral, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Alguien se ha adelantado!',
                style: TextStyle(
                  color: AppColors.accentCoral,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Otro explorador acaba de reclamar el premio principal de este tesoro, '
          'pero aún puedes terminar el recorrido para sumar XP y subir en el Ranking.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.55,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Seguir jugando',
              style: TextStyle(
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUG
  // ─────────────────────────────────────────────────────────────────────────
  void _debugSkipToGpsOk() {
    if (_playerPosition == null) {
      setState(() => _playerPosition = _mapInitialCenter);
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC0D1117), Color(0x000D1117)],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.accentCyan),
        title: Text(
          _huntTitle ?? 'Consola del Tesoro',
          style: const TextStyle(color: AppColors.accentCyan,
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Panel del Master',
            onPressed: _huntId == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminScreen(huntId: _huntId!)),
                    ),
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 160),
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
          Column(
            children: [
              // ── Mapa: ocupa todo el espacio disponible ─────────────────
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:   _mapInitialCenter,
                    initialZoom:     14.0,
                    minZoom: 10.0,   maxZoom: 19.0,
                    backgroundColor: AppColors.backgroundDark,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tileUrl,
                      userAgentPackageName: 'com.tesoro.app',
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
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ]),
                  ],
                ),
              ),

              // ── Panel inferior: tamaño natural, sin desbordamiento ─────
              _dataLoading
                  ? const _LoadingPanel()
                  : _dataError != null
                      ? _ErrorPanel(message: _dataError!, onRetry: _loadData)
                      : _activeClue == null
                          ? const _VictoryPanel()
                          : AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(_shakeAnimation.value * 14, 0),
                                child: child,
                              ),
                              child: ClueBottomPanel(
                                riddleText:     _activeClue!.riddleText,
                                actionState:    _actionState,
                                onCheckIn:      _onCheckIn,
                                onTakePhoto:    _onTakePhoto,
                                stepOrder:      _activeClue!.stepOrder,
                                totalSteps:     _totalSteps,
                                distanceMeters: _distanceMeters,
                              ).animate()
                                  .slideY(begin: 0.3, duration: 400.ms,
                                          curve: Curves.easeOut)
                                  .fadeIn(duration: 300.ms),
                            ),
            ],
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
              bottom: 160,
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

// ─────────────────────────────────────────────────────────────────────────────
class _VictoryPanel extends StatelessWidget {
  const _VictoryPanel();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.cardDark,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_rounded,
            color: AppColors.accentGold, size: 52),
        const SizedBox(height: 12),
        const Text(
          '¡Tesoro encontrado!',
          style: TextStyle(
            color: AppColors.accentGold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Has completado todas las pistas.\nEspera la confirmación del Maestro.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        // ── QR_SCAN_PLACEHOLDER ───────────────────────────────────────────
        // Para activar el escaneo QR físico en la última pista:
        //
        // 1. En pubspec.yaml, descomentar:
        //      mobile_scanner: ^5.1.0
        //    y ejecutar `flutter pub get`.
        //
        // 2. Descomentar el import en este archivo:
        //      import 'package:mobile_scanner/mobile_scanner.dart';
        //
        // 3. Reemplazar el texto de victoria por:
        //      ElevatedButton.icon(
        //        onPressed: () async {
        //          await Navigator.push(context, MaterialPageRoute(
        //            builder: (_) => MobileScanner(
        //              onDetect: (capture) {
        //                final code = capture.barcodes.first.rawValue;
        //                // validar code contra el expected QR del hunt
        //                Navigator.pop(context);
        //              },
        //            ),
        //          ));
        //        },
        //        icon: Icon(Icons.qr_code_scanner_rounded),
        //        label: Text('Escanear QR del tesoro'),
        //      )
        //
        // NOTA: mobile_scanner solo funciona en iOS y Android (no Flutter Web).
        // ─────────────────────────────────────────────────────────────────
      ],
    ),
  ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
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
