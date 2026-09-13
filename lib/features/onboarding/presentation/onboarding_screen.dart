import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      title: 'Instant Doctor Access',
      subtitle:
          'Talk to a real doctor from school in minutes. No clinic visit needed.',
      tag: 'Verified Doctors',
      icon: Icons.medical_services_rounded,
      tagIcon: Icons.verified_user_rounded,
    ),
    _Slide(
      title: 'AI Symptom Check',
      subtitle:
          'Answer a few questions to get an instant risk assessment and clear next steps.',
      tag: 'Smart Triage',
      icon: Icons.psychology_rounded,
      tagIcon: Icons.auto_awesome_rounded,
    ),
    _Slide(
      title: 'Medical History Tracking',
      subtitle:
          'Keep all your visits, clinical notes, and active prescriptions organized in one place.',
      tag: 'Secure & Private',
      icon: Icons.history_edu_rounded,
      tagIcon: Icons.lock_outline_rounded,
    ),
    _Slide(
      title: 'Emergency Support',
      subtitle:
          'Access immediate emergency contacts and ambulance dispatch when it matters most.',
      tag: '24/7 Response',
      icon: Icons.emergency_rounded,
      tagIcon: Icons.flash_on_rounded,
    ),
    _Slide(
      title: 'Medication Reminders',
      subtitle:
          'Never miss a dose with automated schedules and prescription refill alerts.',
      tag: 'Daily Schedule',
      icon: Icons.medication_rounded,
      tagIcon: Icons.alarm_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextOrFinish() {
    if (_index < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      context.go('/role-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Column(
        children: [
          // ── Hero area ────────────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.accent,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top Bar (Brand + Skip shortcut)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_hospital_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SomaCare',
                                style: BloomTextStyles.inter(
                                  size: 16,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.go('/role-selection'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Skip',
                                style: BloomTextStyles.inter(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Slides PageView
                    Expanded(
                      child: PageView.builder(
                        controller: _pageCtrl,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) {
                          final s = _slides[i];
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final shortSide =
                                  constraints.maxWidth < constraints.maxHeight
                                      ? constraints.maxWidth
                                      : constraints.maxHeight;

                              // Generously sized hero illustration container
                              final iconBoxSize =
                                  (shortSide * 0.44).clamp(140.0, 190.0);
                              final iconSize = iconBoxSize * 0.50;

                              return Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Main Hero Card
                                    Container(
                                      width: iconBoxSize,
                                      height: iconBoxSize,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(
                                          iconBoxSize * 0.28,
                                        ),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.12),
                                            blurRadius: 24,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        s.icon,
                                        size: iconSize,
                                        color: Colors.white,
                                      ),
                                    ),

                                    // Feature Badge Pill
                                    Positioned(
                                      bottom: -10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.12),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              s.tagIcon,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              s.tag,
                                              style: BloomTextStyles.inter(
                                                size: 11.5,
                                                weight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Panel (Clean White Card matching Login flow) ───────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false, // Ensures buttons never collide with Android nav bar
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress Dots (Solid primary brand color & soft inactive)
                        Row(
                          children: List.generate(_slides.length, (i) {
                            final active = i == _index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: active ? 24 : 7,
                              height: 5,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),

                        // Title (Primary Sans-Serif)
                        Text(
                          _slides[_index].title,
                          style: BloomTextStyles.inter(
                            size: 22,
                            weight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle (Punchy copy without em-dashes)
                        Text(
                          _slides[_index].subtitle,
                          style: BloomTextStyles.inter(
                            size: 13.5,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            // Skip Button
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      context.go('/role-selection'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: BloomTextStyles.inter(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Next / Get Started Button
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _nextOrFinish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _index == _slides.length - 1
                                        ? 'Get Started'
                                        : 'Next',
                                    style: BloomTextStyles.inter(
                                      size: 14,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final IconData tagIcon;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.tagIcon,
  });
}
