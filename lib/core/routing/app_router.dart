import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding_prefs.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/school_selection_screen.dart';
import '../../features/auth/presentation/student_login_screen.dart';

// ── Doctor imports ────────────────────────────────────────────────────────────
import '../../features/doctor/presentation/doctor_shell.dart';
import '../../features/doctor/presentation/doctor_dashboard_screen.dart';
import '../../features/doctor/presentation/doctor_appointments_screen.dart';
import '../../features/doctor/presentation/doctor_profile_screen.dart';
import '../../features/doctor/presentation/appointment_detail_screen.dart';
import '../../features/doctor/presentation/doctor_consult_screen.dart';
import '../../features/doctor/presentation/student_profile_screen.dart';
import '../../features/doctor/presentation/prescription_writer_screen.dart';
import '../../features/doctor/presentation/encounter_form_screen.dart';
import '../../features/doctor/presentation/doctor_finances_screen.dart';
import '../../features/doctor/presentation/doctor_patients_screen.dart';

import '../../features/doctor/presentation/notifications_screen.dart';
import '../../features/doctor/presentation/doctor_medical_history_management_screen.dart';

// ── Student imports ───────────────────────────────────────────────────────────
import '../../features/student/presentation/student_shell.dart';
import '../../features/student/presentation/student_dashboard_screen.dart';
import '../../features/student/presentation/symptom_check_screen.dart';
import '../../features/student/presentation/book_appointment_screen.dart';
import '../../features/student/presentation/my_appointments_screen.dart';
import '../../features/student/presentation/medical_history_screen.dart';
import '../../features/student/presentation/student_medical_history_view.dart';
import '../../features/student/presentation/prescriptions_screen.dart';
import '../../features/student/presentation/medical_store_screen.dart';
import '../../features/student/presentation/my_medications_screen.dart';
import '../../features/student/presentation/emergency_screen.dart';
import '../../features/student/presentation/consult_screen.dart';
import '../../features/student/presentation/messaging_chat_screen.dart';
import '../../features/student/presentation/records_screen.dart';
import '../../features/student/presentation/profile_screen.dart';
import '../../features/student/presentation/lab_results_screen.dart';
import '../../features/student/presentation/payment_screen.dart';
import '../../features/student/presentation/video_waiting_room_screen.dart';
import '../../features/student/presentation/post_consultation_summary_screen.dart';
import '../../features/student/presentation/ai_result_screen.dart';
import '../../features/student/presentation/ambulance_tracking_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'studentShell',
);
final _doctorShellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'doctorShell',
);

class _SupabaseAuthNotifier extends ChangeNotifier {
  String? _cachedRole;
  String? get cachedRole => _cachedRole;

  void setCachedRole(String? role) {
    _cachedRole = role;
    notifyListeners();
  }

  void clearCachedRole() {
    _cachedRole = null;
    notifyListeners();
  }

  Future<void> refreshRole() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _cachedRole = null;
      notifyListeners();
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      final newRole = profile?['role'] as String?;

      // Only update if we got a valid role from DB
      // Keep existing cached role if DB returns null
      if (newRole != null && newRole.isNotEmpty) {
        _cachedRole = newRole;
      }
      // If DB returns null but we have a cached role, keep it
    } catch (e) {
      // On error, keep existing cached role
    }
    notifyListeners();
  }

  _SupabaseAuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      // Clear cached role on sign out
      if (event.event == AuthChangeEvent.signedOut) {
        _cachedRole = null;
      }
      // Refresh role on sign in or token refresh
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        await refreshRole();
      }
      notifyListeners();
    });
  }
}

/// Lazy-initialised so no network calls fire until the router is actually used.
_SupabaseAuthNotifier? __authNotifier;
_SupabaseAuthNotifier get _authNotifier =>
    __authNotifier ??= _SupabaseAuthNotifier();

/// Public escape hatches for the login screens. `_authNotifier` is
/// file-private, but a login screen needs to update the role the redirect
/// guards below use the instant it knows the real answer - waiting on the
/// `onAuthStateChange` → `refreshRole()` round trip left a window where a
/// stale cached role (usually 'student', left over from a previous session
/// on the same device) was still what `redirect` saw immediately after a
/// *different*-role sign-in, bouncing the user straight back to the old
/// role's dashboard. See `student_login_screen.dart` for where these are
/// called from.
void setCachedAuthRole(String? role) => _authNotifier.setCachedRole(role);
void clearCachedAuthRole() => _authNotifier.clearCachedRole();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/onboarding',
  refreshListenable: _authNotifier,

  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final loggedIn = session != null;
    final loc = state.matchedLocation;

    // Always allow school selection in both flows
    if (loc == '/school-selection') return null;

    final authRoutes = [
      '/onboarding',
      '/role-selection',
      '/student-login',
      '/doctor-login',
    ];
    final isAuthRoute = authRoutes.contains(loc);

    // Onboarding is a one-time, first-run explainer, not a splash screen.
    // Once this install has already seen it (Skip or "Get Started" both
    // record this via `markOnboardingComplete`), never route back to it - // not on a cold start, and not after a later logout/login. Land on
    // role-selection instead, which is the real "signed-out home" screen.
    final onboardingSeen = await hasCompletedOnboarding();
    if (loc == '/onboarding' && onboardingSeen) {
      return loggedIn ? null : '/role-selection';
    }

    // Redirect unauthenticated users to onboarding first, but only if they
    // have never seen it on this device.
    if (!loggedIn && !isAuthRoute) {
      return onboardingSeen ? '/role-selection' : '/onboarding';
    }

    // Route guards: prevent wrong role from accessing wrong dashboard
    if (loggedIn) {
      final role = _authNotifier.cachedRole ?? '';
      // If a student tries to access doctor routes, redirect to student dashboard
      if (role == 'student' &&
          (loc.startsWith('/doctor') ||
              loc == '/appointment-detail' ||
              loc == '/encounter-form' ||
              loc == '/prescription-writer')) {
        return '/student-dashboard';
      }
      // Doctor-only screens whose paths happen to start with `/student-`.
      // These must be excluded from the student-route guard below, or a
      // doctor opening a patient gets bounced back to their own dashboard.
      const doctorOwnedStudentRoutes = <String>{
        '/student-profile',
      };

      // If a doctor tries to access student routes, redirect to doctor dashboard
      if (role == 'doctor' &&
          !doctorOwnedStudentRoutes.contains(loc) &&
          (loc.startsWith('/student-') ||
              loc == '/book-appointment' ||
              loc == '/my-appointments' ||
              loc == '/medical-history' ||
              loc == '/prescriptions' ||
              loc == '/medical-store' ||
              loc == '/my-medications' ||
              loc == '/emergency' ||
              loc == '/lab-results' ||
              loc == '/symptom-check')) {
        return '/doctor-dashboard';
      }
    }

    // Doctor routes bypass the student-specific redirect below
    if (loc.startsWith('/doctor')) return null;
    if (loc == '/appointment-detail') return null;
    if (loc == '/doctor-consult') return null;
    if (loc == '/student-profile') return null;
    if (loc == '/prescription-writer') return null;

    // Only `/onboarding` and `/role-selection` bounce an already-logged-in
    // user back to their dashboard. `/student-login` and `/doctor-login`
    // used to be in this set too, which meant a lingering session from a
    // previous login (Supabase persists sessions on-device) silently sent
    // anyone who opened either login screen straight to their *old*
    // session's dashboard - before they could type new credentials at all.
    // That's the "I entered doctor credentials and it logged me into the
    // student side" report: the doctor credentials were never even checked;
    // the stale student session was still active and this redirect fired
    // first. Login screens now sign out any existing session on entry (see
    // `student_login_screen.dart`) instead of relying on this bounce.
    final bounceIfLoggedIn = loc == '/onboarding' || loc == '/role-selection';
    if (loggedIn && bounceIfLoggedIn) {
      // Use cached role if available
      String role = _authNotifier.cachedRole ?? '';

      // Only fetch from DB if we don't have a cached role yet
      // This is necessary for initial route determination
      if (role.isEmpty) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', session.user.id)
              .maybeSingle();
          role = (profile?['role'] as String?) ?? 'student';
          _authNotifier.setCachedRole(role);
        } catch (e) {
          role = 'student';
        }
      }

      return role == 'doctor' ? '/doctor-dashboard' : '/student-dashboard';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/onboarding',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('onboarding'),
        child: OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/role-selection',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('role-selection'),
        child: RoleSelectionScreen(),
      ),
    ),
    GoRoute(
      path: '/student-login',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('student-login'),
        child: StudentLoginScreen(),
      ),
    ),
    GoRoute(
      path: '/doctor-login',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('doctor-login'),
        child: StudentLoginScreen(),
      ),
    ),

    // ── Doctor shell (bottom nav) ──────────────────────────────────────────
    ShellRoute(
      navigatorKey: _doctorShellNavigatorKey,
      builder: (context, state, child) => DoctorShell(child: child),
      routes: [
        GoRoute(
          path: '/doctor-dashboard',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('doctor-dashboard'),
            child: DoctorDashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/doctor-appointments',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('doctor-appointments'),
            child: DoctorAppointmentsScreen(),
          ),
        ),
        GoRoute(
          path: '/doctor-finances',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('doctor-finances'),
            child: DoctorFinancesScreen(),
          ),
        ),
        GoRoute(
          path: '/doctor-patients',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('doctor-patients'),
            child: DoctorPatientsScreen(),
          ),
        ),
        GoRoute(
          path: '/doctor/student/:id',
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'];
            final extra = s.extra as Map<String, dynamic>? ?? {};
            return MaterialPage(
              key: ValueKey('doctor-student-$id'),
              child: StudentProfileScreen(
                extra: {
                  ...extra,
                  'studentId': id,
                },
              ),
            );
          },
        ),

        GoRoute(
          path: '/doctor-medical-history',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('doctor-medical-history-all'),
            child: DoctorMedicalHistoryManagementScreen(),
          ),
        ),
        GoRoute(
          path: '/doctor-medical-history/:studentId',
          pageBuilder: (c, s) {
            final studentId = s.pathParameters['studentId'];
            return MaterialPage(
              key: ValueKey('doctor-medical-history-${studentId ?? 'none'}'),
              child: DoctorMedicalHistoryManagementScreen(
                studentId: studentId,
              ),
            );
          },
        ),
        GoRoute(
          path: '/doctor-profile',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('doctor-profile'),
            child: DoctorProfileScreen(),
          ),
        ),
      ],
    ),

    // Notifications - outside shell for full-screen
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notifications',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('notifications'),
        child: NotificationsScreen(),
      ),
    ),

    // ── Doctor full-screen sub-routes (outside shell) ──────────────────────
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/appointment-detail',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final appt = extra is Map<String, dynamic>
            ? extra
            : <String, dynamic>{};
        final apptId = appt['id'] as String? ?? '';
        return MaterialPage(
          key: ValueKey(
            'appointment-detail-${apptId.isEmpty ? 'none' : apptId}',
          ),
          child: AppointmentDetailScreen(appointment: appt),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/doctor-consult',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic>
            ? extra
            : <String, dynamic>{};
        final apptId = data['appointmentId'] as String? ?? '';
        return MaterialPage(
          key: ValueKey('doctor-consult-${apptId.isEmpty ? 'none' : apptId}'),
          child: DoctorConsultScreen(extra: data),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/student-profile',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic>
            ? extra
            : <String, dynamic>{};
        final studentId = data['studentId'] as String? ?? '';
        return MaterialPage(
          key: ValueKey(
            'student-profile-${studentId.isEmpty ? 'none' : studentId}',
          ),
          child: StudentProfileScreen(extra: data),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/encounter-form',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic> ? extra : <String, dynamic>{};
        final apptId = data['appointmentId'] as String? ?? '';
        return MaterialPage(
          key: ValueKey('encounter-form-${apptId.isEmpty ? 'none' : apptId}'),
          child: EncounterFormScreen(
            appointmentId: apptId,
            studentName: data['studentName'] as String? ?? 'Patient',
            initialReason: data['reason'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/prescription-writer',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic>
            ? extra
            : <String, dynamic>{};
        final apptId = data['appointmentId'] as String? ?? '';
        return MaterialPage(
          key: ValueKey(
            'prescription-writer-${apptId.isEmpty ? 'none' : apptId}',
          ),
          child: PrescriptionWriterScreen(extra: data),
        );
      },
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/school-selection',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('school-selection'),
        child: SchoolSelectionScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/book-appointment',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('book-appointment'),
        child: BookAppointmentScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medical-history',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('medical-history'),
        child: StudentMedicalHistoryView(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/lab-results',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('lab-results'),
        child: LabResultsScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medical-history-edit',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('medical-history-edit'),
        child: MedicalHistoryScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/prescriptions',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('prescriptions'),
        child: PrescriptionsScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medical-store',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('medical-store'),
        child: MedicalStoreScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/my-medications',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('my-medications'),
        child: MyMedicationsScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/emergency',
      pageBuilder: (c, s) => const MaterialPage(
        key: ValueKey('emergency'),
        child: EmergencyScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ambulance-tracking',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final note = extra is Map<String, dynamic> ? extra['note'] as String? : null;
        return MaterialPage(
          key: const ValueKey('ambulance-tracking'),
          child: AmbulanceTrackingScreen(note: note),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/consult',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic> ? extra : <String, dynamic>{};
        final channelId = data['channelId'] as String?;
        return MaterialPage(
          key: ValueKey('consult-${channelId ?? 'none'}'),
          child: ConsultScreen(
            channelId: channelId,
            doctorName: data['doctorName'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/messaging-chat',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic> ? extra : <String, dynamic>{};
        final doctorName = data['doctorName'] as String? ?? 'Dr. Sarah Martinez';
        return MaterialPage(
          key: ValueKey('messaging-chat-$doctorName'),
          child: MessagingChatScreen(
            doctorName: doctorName,
            doctorSpecialty:
                data['doctorSpecialty'] as String? ?? 'General Physician',
            doctorId: data['doctorId'] as String?,
            appointmentId: data['appointmentId'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/video-waiting-room',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic> ? extra : <String, dynamic>{};
        return MaterialPage(
          key: const ValueKey('video-waiting-room'),
          child: VideoWaitingRoomScreen(
            doctorName: data['doctorName'] as String? ?? 'your doctor',
            channelId: data['channelId'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/post-consultation-summary',
      pageBuilder: (c, s) {
        final extra = s.extra;
        final data = extra is Map<String, dynamic> ? extra : <String, dynamic>{};
        return MaterialPage(
          key: const ValueKey('post-consultation-summary'),
          child: PostConsultationSummaryScreen(
            doctorName: data['doctorName'] as String? ?? 'your doctor',
            durationSeconds: data['durationSeconds'] as int? ?? 0,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payment',
      pageBuilder: (c, s) {
        final extra = s.extra;
        if (extra is! Map<String, dynamic> || extra['onConfirm'] == null) {
          // Missing state (e.g. a page refresh on web) - bounce home rather
          // than crash on the required extra.
          return const MaterialPage(
            key: ValueKey('payment-fallback'),
            child: _MissingBookingRedirect(),
          );
        }
        return MaterialPage(
          key: const ValueKey('payment'),
          child: PaymentScreen(
            doctorName: extra['doctorName'] as String? ?? 'Doctor',
            consultFee: extra['consultFee'] as int? ?? 0,
            platformFee: extra['platformFee'] as int? ?? 0,
            onConfirm: extra['onConfirm'] as Future<void> Function(),
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ai-result',
      pageBuilder: (c, s) {
        final extra = s.extra;
        if (extra is! Map<String, dynamic> || extra['risk'] is! AiRiskLevel) {
          return const MaterialPage(
            key: ValueKey('ai-result-fallback'),
            child: _MissingBookingRedirect(),
          );
        }
        return MaterialPage(
          key: const ValueKey('ai-result'),
          child: AiResultScreen(
            risk: extra['risk'] as AiRiskLevel,
            headline: extra['headline'] as String? ?? 'Assessment complete',
            description: extra['description'] as String? ?? '',
            notes: (extra['notes'] as List?)?.cast<String>() ?? const [],
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/records',
      pageBuilder: (c, s) =>
          const MaterialPage(key: ValueKey('records'), child: RecordsScreen()),
    ),

    // ── Student shell (bottom nav) ─────────────────────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => StudentShell(child: child),
      routes: [
        GoRoute(
          path: '/student-dashboard',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('student-dashboard'),
            child: StudentDashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/symptom-check',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('symptom-check'),
            child: SymptomCheckScreen(),
          ),
        ),
        GoRoute(
          path: '/my-appointments',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('my-appointments'),
            child: MyAppointmentsScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (c, s) => const MaterialPage(
            key: ValueKey('profile'),
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
  ],

  onException: (context, state, router) {
    router.go('/onboarding');
  },
);

/// Shown instead of crashing when a route that requires `extra` state
/// (e.g. `/payment`, `/ai-result`) is entered without it - typically a
/// browser refresh on web, or restored navigation state after the process
/// was killed.
class _MissingBookingRedirect extends StatefulWidget {
  const _MissingBookingRedirect();

  @override
  State<_MissingBookingRedirect> createState() =>
      _MissingBookingRedirectState();
}

class _MissingBookingRedirectState extends State<_MissingBookingRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/student-dashboard');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
