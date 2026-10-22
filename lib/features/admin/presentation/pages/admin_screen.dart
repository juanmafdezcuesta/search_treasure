import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart'; // AppColors
import 'package:consola_tesoro/data/datasources/supabase/hunt_datasource.dart';
import '../widgets/validation_card.dart';

class AdminScreen extends StatefulWidget {
  final String huntId;
  const AdminScreen({super.key, required this.huntId});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final HuntDatasource _huntDS;
  late final TabController  _tabController;

  // ── Pendientes ────────────────────────────────────────────────────────────
  List<PendingValidation> _pending      = [];
  bool                    _pendingLoad  = true;
  String?                 _pendingError;
  final Set<String>       _processingIds = {};

  // ── Validadas ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _validated     = [];
  bool                       _validatedLoad = true;

  @override
  void initState() {
    super.initState();
    _huntDS        = HuntDatasource(_supabase);
    _tabController = TabController(length: 2, vsync: this);
    _loadPending();
    _loadValidated();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Carga de pendientes
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadPending() async {
    setState(() { _pendingLoad = true; _pendingError = null; });
    try {
      final rows = await _supabase.rpc(
        'get_pending_validations',
        params: {'p_hunt_id': widget.huntId},
      ) as List<dynamic>;

      final List<PendingValidation> result = [];
      for (final row in rows) {
        String? signedUrl;
        final photoPath = row['photo_url'] as String?;
        if (photoPath != null && photoPath.isNotEmpty) {
          try {
            signedUrl = await _supabase.storage
                .from('validation_photos')
                .createSignedUrl(photoPath, 3600);
          } catch (_) {}
        }
        result.add(PendingValidation(
          progressId:     row['progress_id']  as String,
          userId:         row['user_id']       as String,
          username:       row['username']      as String,
          avatarUrl:      row['avatar_url']    as String?,
          clueId:         row['clue_id']       as String,
          stepOrder:      (row['step_order']   as num).toInt(),
          riddleText:     row['riddle_text']   as String,
          photoUrl:       photoPath ?? '',
          submittedAt:    DateTime.parse(row['submitted_at'] as String),
          signedPhotoUrl: signedUrl,
        ));
      }
      if (!mounted) return;
      setState(() { _pending = result; _pendingLoad = false; });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() { _pendingError = e.message; _pendingLoad = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _pendingError = e.toString(); _pendingLoad = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Carga de validadas (ganadores)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadValidated() async {
    setState(() => _validatedLoad = true);
    try {
      final rows = await _huntDS.getValidatedProgress(widget.huntId);
      if (!mounted) return;
      setState(() { _validated = rows; _validatedLoad = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _validatedLoad = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aprobar
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _approve(PendingValidation v) async {
    setState(() => _processingIds.add(v.progressId));
    try {
      final result = await _supabase.rpc(
        'approve_validation',
        params: {'p_progress_id': v.progressId},
      ) as Map<String, dynamic>;

      if (!mounted) return;
      final huntCompleted = result['hunt_completed'] as bool? ?? false;
      _removeAndNotify(v,
        message: huntCompleted
            ? '🏆 ¡${v.username} ha encontrado el tesoro!'
            : '✓ Pista ${v.stepOrder} de ${v.username} aprobada',
        color: huntCompleted ? AppColors.accentGold : AppColors.success,
      );
      _loadValidated(); // Refrescar la pestaña de ganadores
    } on PostgrestException catch (e) {
      _showError(v.progressId, e.message);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rechazar
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _confirmReject(PendingValidation v) async {
    final reasonCtrl = TextEditingController();
    final confirmed  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rechazar foto de ${v.username}',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('El jugador podrá volver a intentarlo.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines:   2,
              style:      const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                  hintText:  'Motivo del rechazo (opcional)',
                  hintStyle: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Rechazar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _reject(v, reason: reasonCtrl.text.trim());
  }

  Future<void> _reject(PendingValidation v, {String reason = ''}) async {
    setState(() => _processingIds.add(v.progressId));
    try {
      await _supabase.rpc('reject_validation', params: {
        'p_progress_id': v.progressId,
        'p_reason':      reason.isEmpty ? 'La foto no es válida.' : reason,
      });
      if (!mounted) return;
      _removeAndNotify(v,
          message: '✕ Foto de ${v.username} rechazada',
          color:   AppColors.accentCoral);
    } on PostgrestException catch (e) {
      _showError(v.progressId, e.message);
    }
  }

  void _removeAndNotify(PendingValidation v,
      {required String message, required Color color}) {
    setState(() {
      _processingIds.remove(v.progressId);
      _pending.removeWhere((x) => x.progressId == v.progressId);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showError(String progressId, String msg) {
    if (!mounted) return;
    setState(() => _processingIds.remove(progressId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Error: $msg'), backgroundColor: AppColors.error));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : null,
        elevation: 0,
        foregroundColor: isDark ? AppColors.textPrimary : null,
        iconTheme: isDark ? const IconThemeData(color: AppColors.textPrimary) : null,
        flexibleSpace: isDark ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surfaceDark, Color(0xFF0C1220)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentCyan.withOpacity(0.7),
                      AppColors.accentCyan.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ) : null,
        title: Text('Panel del Maestro',
            style: TextStyle(color: isDark ? AppColors.accentCyan : null,
                fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? AppColors.textPrimary : null),
            tooltip: 'Actualizar',
            onPressed: () { _loadPending(); _loadValidated(); },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          labelColor:     AppColors.accentCyan,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(
              icon: const Icon(Icons.hourglass_top_rounded, size: 18),
              text: 'Pendientes'
                  '${_pending.isEmpty ? '' : ' (${_pending.length})'}',
            ),
            const Tab(
              icon: Icon(Icons.emoji_events_rounded, size: 18),
              text: 'Validadas',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildValidatedTab(),
        ],
      ),
    );
  }

  // ── Pestaña: Pendientes ────────────────────────────────────────────────────
  Widget _buildPendingTab() {
    if (_pendingLoad) {
      return const Center(child: CircularProgressIndicator(
          color: AppColors.accentCyan));
    }
    if (_pendingError != null) {
      return _CenteredMessage(
        icon: Icons.error_outline_rounded, iconColor: AppColors.error,
        message: _pendingError!, actionLabel: 'Reintentar', onAction: _loadPending,
      );
    }
    if (_pending.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.check_circle_outline_rounded, iconColor: AppColors.success,
        message: 'No hay validaciones pendientes.\nTodo al día ✓',
      );
    }
    return RefreshIndicator(
      color: AppColors.accentCyan,
      onRefresh: _loadPending,
      child: ListView.builder(
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   _pending.length,
        itemBuilder: (_, i) {
          final v = _pending[i];
          return ValidationCard(
            validation:   v,
            isProcessing: _processingIds.contains(v.progressId),
            onApprove:    () => _approve(v),
            onReject:     () => _confirmReject(v),
          );
        },
      ),
    );
  }

  // ── Pestaña: Validadas / Ganadores ─────────────────────────────────────────
  Widget _buildValidatedTab() {
    if (_validatedLoad) {
      return const Center(child: CircularProgressIndicator(
          color: AppColors.accentCyan));
    }
    if (_validated.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.search_off_rounded, iconColor: AppColors.textSecondary,
        message: 'Aún no hay pistas validadas.',
      );
    }
    return RefreshIndicator(
      color: AppColors.accentCyan,
      onRefresh: _loadValidated,
      child: ListView.builder(
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   _validated.length,
        itemBuilder: (_, i) => _ValidatedTile(row: _validated[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de validación aprobada (resumen compacto)
// ─────────────────────────────────────────────────────────────────────────────
class _ValidatedTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ValidatedTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final profile     = row['profiles']  as Map<String, dynamic>? ?? {};
    final clue        = row['clues']     as Map<String, dynamic>? ?? {};
    final username    = profile['username']  as String? ?? 'Jugador';
    final avatarUrl   = profile['avatar_url'] as String?;
    final stepOrder   = (clue['step_order']  as num?)?.toInt() ?? 0;
    final riddleText  = clue['riddle_text']  as String? ?? '';
    final validatedAt = row['validated_at']  as String?;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.success.withOpacity(0.15),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.w700))
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(username,
                  style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.success, width: 1),
              ),
              child: Text('Pista $stepOrder',
                  style: const TextStyle(
                      color: AppColors.success, fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(riddleText,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (validatedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                _formatDate(validatedAt),
                style: const TextStyle(
                    color: AppColors.accentCyan, fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 28),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt   = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Hace ${diff.inHours} h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   message;
  final String?  actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 52),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15, height: 1.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon:  const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}
