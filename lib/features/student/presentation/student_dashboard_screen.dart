import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

/// The student's home screen.
///
/// This screen set the visual direction for the product, so its sections are
/// now the shared [AppScreen] / [AppPageHeader] / [AppStatCard] /
/// [AppHeroBanner] / [AppQuickActionGrid] widgets rather than private
/// look-alikes. The doctor dashboard renders from the same widgets, which is
/// what makes the two sides of the app agree.
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String _studentName = '';
  String? _avatarUrl;
  bool _loading = true;
  String? _authError;
  bool _carePlanError = false;

  int _upcomingCount = 0;
  int _medicationsCount = 0;
  Map<String, dynamic>? _nextAppointment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  /// Loads all dashboard streams in parallel and with isolated failure boundaries.
  /// If one stream (such as appointments or medications) fails, the rest of the
  /// dashboard remains completely interactive.
  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _authError = 'You are signed out. Sign in again to access your care plan.';
        });
      }
      return;
    }

    if (mounted && _authError != null) setState(() => _authError = null);

    await Future.wait([
      _loadName(client, userId),
      _loadAppointments(client, userId),
      _loadMedications(client, userId),
    ]);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadName(SupabaseClient client, String userId) async {
    String name = '';
    try {
      final data = await client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
      name = (data?['full_name'] as String?)?.trim() ?? '';
      if (mounted) {
        setState(() => _avatarUrl = data?['avatar_url'] as String?);
      }
    } catch (e) {
      debugPrint('Could not load student name: $e');
    }

    if (name.isEmpty) {
      final email = client.auth.currentUser?.email ?? '';
      name = email.isNotEmpty ? email.split('@').first : '';
    }

    if (mounted) setState(() => _studentName = name);
  }

  Future<void> _loadAppointments(SupabaseClient client, String userId) async {
    try {
      final data = await client
          .from('appointments')
          .select()
          .eq('student_id', userId)
          .order('date', ascending: true)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      final appointments = List<Map<String, dynamic>>.from(data);
      final upcoming = appointments
          .where(
            (a) => const ['pending', 'confirmed']
                .contains((a['status'] as String?) ?? ''),
          )
          .toList()
        ..sort(
          (a, b) => ((a['date'] as String?) ?? '')
              .compareTo((b['date'] as String?) ?? ''),
        );

      if (mounted) {
        setState(() {
          _upcomingCount = upcoming.length;
          _nextAppointment = upcoming.isNotEmpty ? upcoming.first : null;
          _carePlanError = false;
        });
      }
    } catch (e) {
      debugPrint('Student appointments fetch failed: $e');
      if (mounted) {
        setState(() {
          _carePlanError = true;
          _upcomingCount = 0;
          _nextAppointment = null;
        });
      }
    }
  }

  Future<void> _loadMedications(SupabaseClient client, String userId) async {
    try {
      final data = await client
          .from('medications')
          .select('id')
          .eq('student_id', userId)
          .eq('status', 'active')
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      final medications = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() => _medicationsCount = medications.length);
      }
    } catch (e) {
      debugPrint('Student medications fetch failed: $e');
      if (mounted) {
        setState(() => _medicationsCount = 0);
      }
    }
  }

  // ── Presentation ───────────────────────────────────────────────────────────

  List<AppQuickAction> get _quickActions => [
    AppQuickAction(
      label: 'Message a doctor',
      category: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      color: AppColors.fillBlue,
      // Messaging needs a specific doctor thread to open (see
      // MessagingChatScreen); route through appointments, where the
      // Message action on a confirmed appointment carries that context.
      onTap: () => context.push('/my-appointments'),
    ),
    AppQuickAction(
      label: 'Book appointment',
      category: 'Scheduling',
      icon: Icons.calendar_today_outlined,
      color: AppColors.fillTeal,
      onTap: () => context.push('/book-appointment'),
    ),
    AppQuickAction(
      label: 'My appointments',
      category: 'Calendar',
      icon: Icons.event_note_outlined,
      color: AppColors.fillPurple,
      onTap: () => context.go('/my-appointments'),
    ),
    AppQuickAction(
      label: 'Medical history',
      category: 'Records',
      icon: Icons.folder_open_outlined,
      color: AppColors.fillAmber,
      onTap: () => context.push('/medical-history'),
    ),
    AppQuickAction(
      label: 'Prescriptions',
      category: 'Pharmacy',
      icon: Icons.description_outlined,
      color: AppColors.fillBlue,
      onTap: () => context.push('/prescriptions'),
    ),
    AppQuickAction(
      label: 'Medical store',
      category: 'Shop',
      icon: Icons.storefront_outlined,
      color: AppColors.fillTeal,
      onTap: () => context.push('/medical-store'),
    ),
    AppQuickAction(
      label: 'My medications',
      category: 'Reminders',
      icon: Icons.medication_outlined,
      color: AppColors.fillPurple,
      onTap: () => context.push('/my-medications'),
    ),
    AppQuickAction(
      label: 'Lab results',
      category: 'Results',
      icon: Icons.science_outlined,
      color: AppColors.fillAmber,
      onTap: () => context.push('/lab-results'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: AppPageHeader(
            title: _studentName.isNotEmpty
                ? 'Hello, $_studentName 👋'
                : 'Hello there 👋',
            subtitle: 'How are you feeling today?',
            actions: [
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Semantics(
                  button: true,
                  label: 'Your profile',
                  child: AppAvatar(
                    name: _studentName,
                    size: 42,
                    imageUrl: _avatarUrl,
                  ),
                ),
              ),
              AppCircleButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
        ),

        if (_authError != null)
          appSection(AppErrorState(message: _authError!, onRetry: _load))
        else ...[
          // ── Stat Row ───────────────────────────────────────────────────────
          appSection(
            AppStatRow(
              cards: [
                AppStatCard(
                  icon: Icons.event_available_rounded,
                  value: '$_upcomingCount',
                  label: 'Upcoming\nappointments',
                  color: AppColors.primary,
                  loading: _loading,
                  onTap: () => context.go('/my-appointments'),
                ),
                AppStatCard(
                  icon: Icons.medication_outlined,
                  value: '$_medicationsCount',
                  label: 'Active\nmedications',
                  color: AppColors.success,
                  loading: _loading,
                  onTap: () => context.push('/my-medications'),
                ),
              ],
            ),
          ),

          // ── Care Plan / Upcoming Visit Section ─────────────────────────────
          if (_nextAppointment != null)
            appSection(
              _UpcomingVisitCard(
                appointment: _nextAppointment!,
                onJoin: () => context.push(
                  '/video-waiting-room',
                  extra: {
                    'doctorName':
                        _nextAppointment!['doctor_name'] as String? ??
                        'your doctor',
                    'channelId': 'appointment_${_nextAppointment!['id']}',
                  },
                ),
                onReschedule: () => context.go('/my-appointments'),
              ),
            )
          else if (_carePlanError)
            appSection(
              _CarePlanErrorCard(onRetry: _load),
            )
          else if (!_loading)
            appSection(
              _CarePlanEmptyCard(
                onBook: () => context.push('/book-appointment'),
              ),
            ),

          // ── Urgent Care Hero Banner ────────────────────────────────────────
          appSection(
            AppHeroBanner(
              icon: Icons.emergency_outlined,
              eyebrow: 'URGENT CARE',
              title: 'Talk to a doctor in minutes',
              subtitle:
                  'For symptoms that need attention now, connect with an '
                  'on-call doctor right away.',
              gradient: const [AppColors.error, AppColors.errorDark],
              primaryLabel: 'CONNECT NOW',
              onPrimary: () => context.push('/emergency'),
              secondaryLabel: 'My requests',
              onSecondary: () => context.go('/my-appointments'),
            ),
            bottom: AppSpacing.md,
          ),

          // ── AI Symptom Checker ─────────────────────────────────────────────
          appSection(
            AppHeroBanner(
              icon: Icons.psychology_outlined,
              eyebrow: 'AI SYMPTOM CHECKER',
              title: 'Describe your symptoms',
              subtitle:
                  "Get instant AI-guided insight into what you're feeling and "
                  'what to do next.',
              gradient: const [AppColors.accent, AppColors.accentDark],
              primaryLabel: 'START CHECK',
              onPrimary: () => context.go('/symptom-check'),
            ),
          ),

          // ── Medication Reminder (if active) ────────────────────────────────
          if (!_loading && _medicationsCount > 0)
            appSection(
              _MedicationReminderCard(
                count: _medicationsCount,
                onTap: () => context.push('/my-medications'),
              ),
            ),

          // ── Quick Actions Grid ─────────────────────────────────────────────
          appSection(
            const AppSectionTitle(title: 'Quick actions'),
            bottom: AppSpacing.md,
          ),
          appSection(AppQuickActionGrid(actions: _quickActions)),
        ],
      ],
    );
  }
}

// ─── Cards ───────────────────────────────────────────────────────────────────

/// The student's counterpart to the doctor's "next patient" card.
class _UpcomingVisitCard extends StatelessWidget {
  const _UpcomingVisitCard({
    required this.appointment,
    required this.onJoin,
    required this.onReschedule,
  });

  final Map<String, dynamic> appointment;
  final VoidCallback onJoin;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final doctorName = appointment['doctor_name'] as String? ?? 'Your doctor';
    final specialty = (appointment['doctor_specialty'] as String?) ?? '';
    final date = (appointment['date'] as String?) ?? '';
    final time = (appointment['time'] as String?) ?? '';
    final status = (appointment['status'] as String?) ?? 'pending';
    final isConfirmed = status == 'confirmed';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'UPCOMING VISIT',
                  style: BloomTextStyles.eyebrow(),
                ),
              ),
              if (date.isNotEmpty || time.isNotEmpty)
                Text(
                  [date, time].where((s) => s.isNotEmpty).join(' · '),
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
              AppAvatar(name: doctorName, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doctorName,
                      style: BloomTextStyles.inter(
                        size: AppTypography.titleMedium,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (specialty.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        specialty,
                        style: BloomTextStyles.inter(
                          size: AppTypography.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
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
                child: ElevatedButton(
                  onPressed: isConfirmed ? onJoin : onReschedule,
                  child: Text(
                    isConfirmed ? 'Join visit' : 'Awaiting payment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReschedule,
                  child: const Text('Reschedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline card shown when upcoming visits could not be loaded, allowing
/// the rest of the home screen to remain fully functional.
class _CarePlanErrorCard extends StatelessWidget {
  const _CarePlanErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.errorWash,
      borderColor: AppColors.errorTint,
      child: Row(
        children: [
          const AppIconChip(
            icon: Icons.sync_problem_rounded,
            color: AppColors.error,
            size: 38,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Care plan offline',
                  style: BloomTextStyles.inter(
                    size: AppTypography.titleSmall,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Unable to load scheduled visits. Pull down to refresh.',
                  style: BloomTextStyles.inter(
                    size: AppTypography.bodySmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.error),
            tooltip: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Inline card shown when no upcoming visits are scheduled.
class _CarePlanEmptyCard extends StatelessWidget {
  const _CarePlanEmptyCard({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const AppIconChip(
            icon: Icons.event_available_outlined,
            color: AppColors.primary,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No upcoming visits',
                  style: BloomTextStyles.inter(
                    size: AppTypography.titleSmall,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Schedule an appointment with a doctor anytime.',
                  style: BloomTextStyles.inter(
                    size: AppTypography.bodySmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onBook,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            child: const Text('Book visit'),
          ),
        ],
      ),
    );
  }
}

/// Amber prompt that leads into the medication reminder list.
class _MedicationReminderCard extends StatelessWidget {
  const _MedicationReminderCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.warningWash,
      borderColor: AppColors.warningTint,
      semanticLabel:
          'Medication reminders. You have $count active '
          'medication${count == 1 ? '' : 's'}.',
      child: Row(
        children: [
          const AppIconChip(
            icon: Icons.medication_outlined,
            color: AppColors.warningDark,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Medication reminders',
                  style: BloomTextStyles.inter(
                    size: AppTypography.titleSmall,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  'You have $count active '
                  'medication${count == 1 ? '' : 's'}',
                  style: BloomTextStyles.inter(
                    size: AppTypography.bodyMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
