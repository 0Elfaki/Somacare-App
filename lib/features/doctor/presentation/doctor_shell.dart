import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

/// The doctor side's persistent chrome.
///
/// Uses the same [AppBottomNav] as the student shell - the only difference is
/// the accent colour and the set of destinations.
class DoctorShell extends StatelessWidget {
  const DoctorShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final isHome = loc.startsWith('/doctor-dashboard');

    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isHome) context.go('/doctor-dashboard');
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: child,
        bottomNavigationBar: const _DoctorBottomNav(),
      ),
    );
  }
}

class _DoctorBottomNav extends StatelessWidget {
  const _DoctorBottomNav();

  static const _tabs = <String>[
    '/doctor-dashboard',
    '/doctor-appointments',
    '/doctor-patients',
    '/doctor-profile',
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(loc);

    return AppBottomNav(
      currentIndex: index,
      accent: AppColors.doctorAccent,
      destinations: [
        AppNavDestination(
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view_rounded,
          label: 'Home',
          onTap: () => context.go('/doctor-dashboard'),
        ),
        AppNavDestination(
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_month_rounded,
          label: 'Schedule',
          onTap: () => context.go('/doctor-appointments'),
        ),
        AppNavDestination(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'Patients',
          onTap: () => context.go('/doctor-patients'),
        ),
        AppNavDestination(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          onTap: () => context.go('/doctor-profile'),
        ),
      ],
    );
  }
}
