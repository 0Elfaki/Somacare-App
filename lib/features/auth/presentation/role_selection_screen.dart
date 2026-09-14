import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Welcome to SomaCare',
                  style: BloomTextStyles.inter(
                    size: 22,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Who are you logging in as?',
                  style: BloomTextStyles.inter(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // ✅ Student - push to student-login, no extra needed
              _RoleCard(
                icon: Icons.school_rounded,
                title: 'Student',
                subtitle: 'Access health services,\nbook appointments & more',
                color: AppColors.primaryLight,
                onTap: () => context.push('/student-login'),
              ),
              const SizedBox(height: 16),

              // ✅ Doctor - pass role:'doctor' so login screen auto-selects Doctor tab
              _RoleCard(
                icon: Icons.medical_services_rounded,
                title: 'Doctor',
                subtitle:
                    'Manage appointments,\nview patient records & consult',
                color: AppColors.success,
                onTap: () => context.push(
                  '/doctor-login',
                  extra: const {'role': 'doctor'},
                ),
              ),

              const Spacer(),
              Center(
                child: Text(
                  'Powered by SomaCare v2.0',
                  style: BloomTextStyles.inter(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: onTap,
      border: Border.all(color: color.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: BloomTextStyles.inter(
                    size: 16,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: BloomTextStyles.inter(
                    size: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: color.withValues(alpha: 0.6),
            size: 16,
          ),
        ],
      ),
    );
  }
}
