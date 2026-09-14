import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../data/notification_service.dart';

/// The doctor's home screen.
///
/// Structurally identical to the student dashboard: a greeting header, a row
/// of live stat cards, a hero banner for whatever needs attention now, a
/// quick-action grid, then the day's list. It is built from the same
/// [AppScreen] / [AppCard] / [AppStatCard] kit, so the two sides of the app
/// finally read as one product.
///
/// The previous version laid these sections out in a fixed [Column] with a
/// single [Expanded] at the bottom, inside a [RefreshIndicator] that had no
/// scrollable to drive it. On a small phone that overflowed, and pull-to-
/// refresh did nothing. It is now a sliver list that scrolls properly.
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _todayAppointments = const [];
  List<Map<String, dynamic>> _emergencyAppointments = const [];
  List<Map<String, dynamic>> _pendingApprovals = const [];

  int _unreadNotifications = 0;
  int _todayCountTotal = 0;
  int _emergencyCountTotal = 0;
  int _completedTodayCount = 0;

  bool _loading = true;
  String? _error;

  RealtimeChannel? _appointmentsChannel;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToAppointments();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    final channel = _appointmentsChannel;
    if (channel != null) {
      // `removeChannel` both unsubscribes and drops the client-side reference;
      // `unsubscribe()` alone leaves the channel registered on the client.
      Supabase.instance.client.removeChannel(channel);
      _appointmentsChannel = null;
    }
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  /// Re-subscribes the dashboard to appointment changes for this doctor so the
  /// list updates when a student books, cancels or reschedules.
  void _subscribeToAppointments() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _appointmentsChannel = Supabase.instance.client
        .channel('doctor_appointments_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'doctor_id',
            value: userId,
          ),
          callback: (_) {
            // A burst of row changes should cause one reload, not ten.
            _refreshDebounce?.cancel();
            _refreshDebounce = Timer(const Duration(milliseconds: 600), () {
              if (mounted) _loadData();
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'You are signed out. Sign in again to see your schedule.';
        });
      }
      return;
    }

    if (mounted && _error != null) setState(() => _error = null);

    final today = DateTime.now().toIso8601String().split('T').first;

    try {
      // Each query carries its own timeout and fallback, so one missing table
      // cannot blank the whole dashboard.
      final results = await Future.wait<dynamic>([
        client
            .from('appointments')
            .select()
            .eq('doctor_id', userId)
            .eq('is_emergency', true)
            .order('created_at', ascending: false)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => <Map<String, dynamic>>[],
            ),
        client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 8), onTimeout: () => null),
        client
            .from('appointments')
            .select()
            .eq('doctor_id', userId)
            .eq('date', today)
            .order('time', ascending: true)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => <Map<String, dynamic>>[],
            ),
        NotificationService.getUnreadNotifications(userId).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <Map<String, dynamic>>[],
        ),
        client
            .from('appointments')
            .select('student_id')
            .eq('doctor_id', userId)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => <Map<String, dynamic>>[],
            ),
      ], eagerError: false);

      final rawEmergency = List<Map<String, dynamic>>.from(
        (results[0] as List?) ?? const [],
      );
      final rawToday = List<Map<String, dynamic>>.from(
        (results[2] as List?) ?? const [],
      );
      final allAppointments = (results[4] as List?) ?? const [];

      final studentIds = allAppointments
          .map((a) => (a as Map)['student_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // The appointment rows carry only `student_id`. Resolve the names once
      // here so every card shows a person rather than the word "Student".
      final names = await _resolveStudentNames(studentIds);
      for (final row in [...rawEmergency, ...rawToday]) {
        row['student_name'] =
            names[row['student_id']] ?? row['student_name'] ?? 'Patient';
      }

      final approvals = await _loadPendingApprovals(studentIds, names);

      if (!mounted) return;
      setState(() {
        _profile = results[1] as Map<String, dynamic>?;
        _emergencyAppointments = rawEmergency.take(5).toList();
        _emergencyCountTotal = rawEmergency
            .where((a) => (a['status'] as String?) != 'completed')
            .length;
        _todayAppointments = rawToday.take(6).toList();
        _todayCountTotal = rawToday.length;
        _completedTodayCount = rawToday
            .where((a) => a['status'] == 'completed')
            .length;
        _unreadNotifications = (results[3] as List?)?.length ?? 0;
        _pendingApprovals = approvals;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Doctor dashboard load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Only surface an error when there is nothing at all to show; a
        // partial failure on a refresh should not wipe out good data.
        if (_todayAppointments.isEmpty && _emergencyAppointments.isEmpty) {
          _error = "We couldn't load your schedule. Check your connection "
              'and try again.';
        }
      });
    }
  }

  Future<Map<String, String>> _resolveStudentNames(List<String> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => <Map<String, dynamic>>[],
          );
      return {
        for (final r in rows)
          if (r['id'] is String && (r['full_name'] as String?)?.isNotEmpty
              == true)
            r['id'] as String: r['full_name'] as String,
      };
    } catch (e) {
      debugPrint('Could not resolve student names: $e');
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingApprovals(
    List<String> studentIds,
    Map<String, String> names,
  ) async {
    if (studentIds.isEmpty) return const [];
    try {
      final histories = await Supabase.instance.client
          .from('medical_histories')
          .select('id, student_id, updated_at')
          .inFilter('student_id', studentIds)
          .eq('is_approved', false)
          .isFilter('denial_reason', null)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      return [
        for (final h in histories)
          {
            ...h,
            'student_name': names[h['student_id']] ?? 'Unknown patient',
          },
      ];
    } catch (e) {
      debugPrint('Could not load pending approvals: $e');
      return const [];
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approveHistory(String historyId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('medical_histories')
          .update({
            'is_approved': true,
            'approved_by': userId,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', historyId);

      if (!mounted) return;
      showAppSnack(
        context,
        'Record approved. The patient can download it now.',
        tone: AppStatusTone.success,
      );
      await _loadData();
    } catch (e) {
      debugPrint('Approve failed: $e');
      if (!mounted) return;
      showAppSnack(
        context,
        "That didn't go through. Please try again.",
        tone: AppStatusTone.danger,
      );
    }
  }

  Future<void> _denyHistory(String historyId) async {
    final reason = await _askDenialReason();
    if (reason == null || reason.trim().isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('medical_histories')
          .update({
            'is_approved': false,
            'denial_reason': reason.trim(),
            'denied_by': userId,
            'denied_at': DateTime.now().toIso8601String(),
          })
          .eq('id', historyId);

      if (!mounted) return;
      showAppSnack(
        context,
        'Record denied. The patient will see your reason.',
        tone: AppStatusTone.warning,
      );
      await _loadData();
    } catch (e) {
      debugPrint('Deny failed: $e');
      if (!mounted) return;
      showAppSnack(
        context,
        "That didn't go through. Please try again.",
        tone: AppStatusTone.danger,
      );
    }
  }

  /// Asks for a denial reason. The controller lives for exactly as long as the
  /// dialog and is disposed in a `finally`, which the old version never did.
  Future<String?> _askDenialReason() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final formKey = GlobalKey<FormState>();
          return AlertDialog(
            title: const Text('Deny this record?'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The patient will see this reason, so be specific about '
                    'what needs to change.',
                    style: BloomTextStyles.inter(
                      size: AppTypography.bodyMedium,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: controller,
                    maxLines: 3,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Reason for denial',
                      hintText: 'e.g. Allergy list is incomplete',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5)
                        ? 'Please give the patient a reason (5+ characters).'
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(dialogContext).pop(controller.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Deny record'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  // ── Presentation helpers ───────────────────────────────────────────────────

  String get _doctorName {
    final raw = (_profile?['full_name'] as String?)?.trim() ?? '';
    if (raw.isEmpty) return 'Doctor';
    return raw.toLowerCase().startsWith('dr') ? raw : 'Dr. $raw';
  }

  String get _specialization =>
      (_profile?['specialization'] as String?)?.trim().isNotEmpty == true
      ? _profile!['specialization'] as String
      : 'General Practice';

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// The next appointment today that has not been seen yet.
  Map<String, dynamic>? get _nextUp {
    for (final a in _todayAppointments) {
      final status = (a['status'] as String?) ?? '';
      if (status != 'completed' && status != 'cancelled') return a;
    }
    return null;
  }

  List<AppQuickAction> get _quickActions => [
    AppQuickAction(
      label: 'All appointments',
      category: 'Schedule',
      icon: Icons.event_note_outlined,
      color: AppColors.primary,
      onTap: () => context.go('/doctor-appointments'),
    ),
    AppQuickAction(
      label: 'My patients',
      category: 'Records',
      icon: Icons.people_outline_rounded,
      color: AppColors.success,
      onTap: () => context.go('/doctor-patients'),
    ),
    AppQuickAction(
      label: 'Medical histories',
      category: 'Review',
      icon: Icons.folder_open_outlined,
      color: AppColors.accent,
      onTap: () => context.push('/doctor-medical-history'),
    ),
    AppQuickAction(
      label: 'Earnings',
      category: 'Finance',
      icon: Icons.account_balance_wallet_outlined,
      color: AppColors.warning,
      onTap: () => context.push('/doctor-finances'),
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      accent: AppColors.doctorAccent,
      onRefresh: _loadData,
      slivers: [
        SliverToBoxAdapter(
          child: AppPageHeader(
            title: _loading && _profile == null
                ? 'Loading…'
                : 'Hello, $_doctorName 👋',
            subtitle: '$_greeting · $_specialization',
            actions: [
              GestureDetector(
                onTap: () => context.push('/doctor-profile'),
                child: Semantics(
                  button: true,
                  label: 'Your profile',
                  child: AppAvatar(
                    name: _doctorName,
                    size: 42,
                    color: AppColors.doctorAccent,
                  ),
                ),
              ),
              AppCircleButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                badgeCount: _unreadNotifications,
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
        ),

        if (_error != null)
          appSection(AppErrorState(message: _error!, onRetry: _loadData))
        else ...[
          // ── Stats ─────────────────────────────────────────────────────────
          appSection(
            AppStatRow(
              cards: [
                AppStatCard(
                  icon: Icons.event_available_rounded,
                  value: '$_todayCountTotal',
                  label: "Today's\nappointments",
                  color: AppColors.primary,
                  loading: _loading,
                  onTap: () => context.go('/doctor-appointments'),
                ),
                AppStatCard(
                  icon: Icons.emergency_outlined,
                  value: '$_emergencyCountTotal',
                  label: 'Open\nemergencies',
                  color: AppColors.error,
                  loading: _loading,
                  onTap: () =>
                      context.go('/doctor-appointments?status=emergency'),
                ),
                AppStatCard(
                  icon: Icons.check_circle_outline_rounded,
                  value: '$_completedTodayCount',
                  label: 'Completed\ntoday',
                  color: AppColors.success,
                  loading: _loading,
                  onTap: () =>
                      context.go('/doctor-appointments?status=completed'),
                ),
              ],
            ),
          ),

          // ── Next up ───────────────────────────────────────────────────────
          if (_nextUp != null)
            appSection(
              _NextPatientCard(
                appointment: _nextUp!,
                onOpen: () =>
                    context.push('/appointment-detail', extra: _nextUp),
                onStartConsult: () => context.push(
                  '/doctor-consult',
                  extra: {
                    'appointmentId': _nextUp!['id'],
                    'studentName': _nextUp!['student_name'],
                    'channelId': 'appointment_${_nextUp!['id']}',
                  },
                ),
              ),
            ),

          // ── Emergencies ───────────────────────────────────────────────────
          if (_emergencyCountTotal > 0)
            appSection(
              AppHeroBanner(
                icon: Icons.emergency_outlined,
                eyebrow: 'URGENT CARE',
                title: _emergencyCountTotal == 1
                    ? '1 patient needs you now'
                    : '$_emergencyCountTotal patients need you now',
                subtitle:
                    'Emergency requests are waiting for a response. Open the '
                    'queue to triage them.',
                gradient: const [AppColors.error, AppColors.errorDark],
                primaryLabel: 'OPEN QUEUE',
                onPrimary: () =>
                    context.go('/doctor-appointments?status=emergency'),
              ),
            ),

          if (_emergencyAppointments.isNotEmpty) ...[
            appSection(
              AppSectionTitle(
                title: 'Emergency requests',
                count: _emergencyCountTotal,
                actionLabel: 'See all',
                onAction: () =>
                    context.go('/doctor-appointments?status=emergency'),
              ),
              bottom: AppSpacing.md,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              sliver: SliverList.separated(
                itemCount: _emergencyAppointments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final a = _emergencyAppointments[i];
                  return _AppointmentRow(
                    appointment: a,
                    emergency: true,
                    onTap: () =>
                        context.push('/appointment-detail', extra: a),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

          // ── Pending approvals ─────────────────────────────────────────────
          if (_pendingApprovals.isNotEmpty) ...[
            appSection(
              AppSectionTitle(
                title: 'Records awaiting approval',
                count: _pendingApprovals.length,
              ),
              bottom: AppSpacing.md,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              sliver: SliverList.separated(
                itemCount: _pendingApprovals.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final approval = _pendingApprovals[i];
                  final id = approval['id'] as String? ?? '';
                  return _ApprovalCard(
                    studentName:
                        approval['student_name'] as String? ?? 'Patient',
                    onReview: () => context.push(
                      '/doctor-medical-history/${approval['student_id']}',
                    ),
                    onApprove: id.isEmpty ? null : () => _approveHistory(id),
                    onDeny: id.isEmpty ? null : () => _denyHistory(id),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],

          // ── Quick actions ─────────────────────────────────────────────────
          appSection(
            const AppSectionTitle(title: 'Quick actions'),
            bottom: AppSpacing.md,
          ),
          appSection(AppQuickActionGrid(actions: _quickActions)),

          // ── Today's schedule ──────────────────────────────────────────────
          appSection(
            AppSectionTitle(
              title: "Today's schedule",
              count: _todayCountTotal,
              actionLabel: _todayCountTotal > _todayAppointments.length
                  ? 'See all'
                  : null,
              onAction: _todayCountTotal > _todayAppointments.length
                  ? () => context.go('/doctor-appointments')
                  : null,
            ),
            bottom: AppSpacing.md,
          ),

          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, _) => const AppSkeletonRow(),
              ),
            )
          else if (_todayAppointments.isEmpty)
            appSection(
              AppEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nothing booked today',
                message:
                    'When a patient books a consultation with you, it will '
                    'appear here with their reason for the visit.',
                actionLabel: 'View the full schedule',
                onAction: () => context.go('/doctor-appointments'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              sliver: SliverList.separated(
                itemCount: _todayAppointments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final a = _todayAppointments[i];
                  return _AppointmentRow(
                    appointment: a,
                    onTap: () =>
                        context.push('/appointment-detail', extra: a),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Cards ───────────────────────────────────────────────────────────────────

/// The doctor-side counterpart of the student's "upcoming visit" card.
class _NextPatientCard extends StatelessWidget {
  const _NextPatientCard({
    required this.appointment,
    required this.onOpen,
    required this.onStartConsult,
  });

  final Map<String, dynamic> appointment;
  final VoidCallback onOpen;
  final VoidCallback onStartConsult;

  @override
  Widget build(BuildContext context) {
    final name = appointment['student_name'] as String? ?? 'Patient';
    final time = appointment['time'] as String? ?? '';
    final reason = (appointment['reason'] as String?)?.trim() ?? '';
    final status = appointment['status'] as String? ?? 'pending';
    final canStart = status == 'confirmed' || status == 'in_progress';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NEXT PATIENT',
                  style: BloomTextStyles.eyebrow(color: AppColors.primary),
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: BloomTextStyles.mono(
                    size: AppTypography.labelMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppAvatar(name: name, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: BloomTextStyles.inter(
                        size: AppTypography.titleMedium,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: BloomTextStyles.inter(
                          size: AppTypography.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusChip.fromStatus(status, dense: true),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canStart ? onStartConsult : onOpen,
                  icon: Icon(
                    canStart
                        ? Icons.videocam_rounded
                        : Icons.description_outlined,
                    size: 18,
                  ),
                  label: Text(canStart ? 'Start consult' : 'Review'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  child: const Text('Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One appointment in a list.
class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    required this.appointment,
    required this.onTap,
    this.emergency = false,
  });

  final Map<String, dynamic> appointment;
  final VoidCallback onTap;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    final name = appointment['student_name'] as String? ?? 'Patient';
    final time = appointment['time'] as String? ?? '';
    final date = appointment['date'] as String? ?? '';
    final reason = (appointment['reason'] as String?)?.trim() ?? '';
    final status = appointment['status'] as String? ?? 'pending';

    return AppListRow(
      onTap: onTap,
      showChevron: false,
      leading: emergency
          ? const AppIconChip(
              icon: Icons.emergency_rounded,
              color: AppColors.error,
            )
          : AppAvatar(name: name),
      title: name,
      subtitle: reason.isEmpty ? 'No reason given' : reason,
      meta: [
        if (time.isNotEmpty) time,
        if (emergency && date.isNotEmpty) date,
      ].join('  ·  '),
      trailing: AppStatusChip.fromStatus(
        emergency && status == 'pending' ? 'urgent' : status,
        dense: true,
      ),
    );
  }
}

/// A medical record waiting on the doctor's approval.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.studentName,
    required this.onReview,
    required this.onApprove,
    required this.onDeny,
  });

  final String studentName;
  final VoidCallback onReview;
  final VoidCallback? onApprove;
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconChip(
                icon: Icons.fact_check_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      studentName,
                      style: BloomTextStyles.inter(
                        size: AppTypography.titleSmall,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wants to download their medical record',
                      style: BloomTextStyles.inter(
                        size: AppTypography.bodyMedium,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AppStatusChip(
                label: 'Pending',
                tone: AppStatusTone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReview,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppTouch.minTarget),
                  ),
                  child: const Text('Review'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDeny,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(AppTouch.minTarget),
                  ),
                  child: const Text('Deny'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(AppTouch.minTarget),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
