import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _profileImageBase64;
  // Session-only: no local-storage or backend column is wired up for this
  // yet, so it doesn't survive an app restart, but it's a real toggle now
  // rather than a switch that silently ignored every tap.
  bool _notificationsEnabled = true;

  final _nameCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _workingHoursCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specializationCtrl.dispose();
    _licenseCtrl.dispose();
    _workingHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profile = data;
          _nameCtrl.text = (data?['full_name'] as String?) ?? '';
          _specializationCtrl.text = (data?['specialization'] as String?) ?? '';
          _licenseCtrl.text = (data?['license_number'] as String?) ?? '';
          _workingHoursCtrl.text =
              (data?['working_hours'] as String?) ?? '09:00 - 17:00';
          // Load profile image if exists
          _profileImageBase64 = data?['avatar_url'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _nameCtrl.text.trim(),
            'specialization': _specializationCtrl.text.trim(),
            'license_number': _licenseCtrl.text.trim(),
            'working_hours': _workingHoursCtrl.text.trim(),
          })
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _profile = {
            ...?_profile,
            'full_name': _nameCtrl.text.trim(),
            'specialization': _specializationCtrl.text.trim(),
            'license_number': _licenseCtrl.text.trim(),
            'working_hours': _workingHoursCtrl.text.trim(),
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.smAll,
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/onboarding');
    }
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => StatefulBuilder(
          builder: (sheetCtx, setModalState) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Manage notification preferences',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (v) =>
                        setModalState(() => _notificationsEnabled = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                const _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  subtitle: 'Coming soon',
                  trailing: Switch(
                    value: false,
                    onChanged: null,
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () => _showInfoDialog(
                    sheetCtx,
                    icon: Icons.language_outlined,
                    title: 'Language',
                    message:
                        'Language preferences are currently locked to English for this campus portal.',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Privacy',
                  subtitle: 'Manage your data and privacy',
                  onTap: () => _showInfoDialog(
                    sheetCtx,
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    message:
                        'For questions about how your data is collected, '
                        'used, and protected, contact your clinical '
                        'director or campus IT. The in-app privacy policy '
                        'viewer isn\'t available yet.',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.security_outlined,
                  title: 'Security',
                  subtitle: 'Password and authentication',
                  onTap: () => _sendPasswordReset(sheetCtx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(
    BuildContext dialogContext, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// The "Security" settings tile doesn't have a real change-password screen
  /// to link to, so this sends a genuine Supabase password-reset email to
  /// the signed-in doctor's own address instead of doing nothing.
  Future<void> _sendPasswordReset(BuildContext dialogContext) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!dialogContext.mounted) return;
      _showInfoDialog(
        dialogContext,
        icon: Icons.security_outlined,
        title: 'Security',
        message:
            'A password reset link has been sent to $email. Follow it to '
            'set a new password.',
      );
    } catch (e) {
      if (!dialogContext.mounted) return;
      _showInfoDialog(
        dialogContext,
        icon: Icons.error_outline,
        title: 'Security',
        message: userFriendlyErrorMessage(
          e,
          defaultMessage:
              'Could not send the password reset email. Please try again.',
        ),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Help & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help? Here are some options:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.mail_outline, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text('Email: support@somacare.ug'),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.call_outlined, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text('Phone: +1 234 567 890'),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text('Chat: Available 24/7'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support team will contact you soon!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Somacare'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 2.0.0 2026',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'A comprehensive telemedicine platform for school healthcare.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text(
              '© 2026 Somacare\nAll rights reserved.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper to decode base64 image
  Widget _buildProfileImage() {
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      try {
        // Check if it's a URL or base64
        if (_profileImageBase64!.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.network(
              _profileImageBase64!,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(),
            ),
          );
        } else {
          // It's base64 encoded
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.memory(
              base64Decode(_profileImageBase64!),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(),
            ),
          );
        }
      } catch (e) {
        return _buildDefaultAvatar();
      }
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.success, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.medical_services_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final fullName = (_profile?['full_name'] as String?) ?? 'Doctor';
    final specialization =
        (_profile?['specialization'] as String?) ?? 'General Practice';

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;
                final maxContentWidth = isTablet ? 560.0 : double.infinity;
                final horizontalPadding = isTablet ? 24.0 : 20.0;

                return CustomScrollView(
                  slivers: [
                    // ── Header ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          MediaQuery.of(context).padding.top + 20,
                          horizontalPadding,
                          40,
                        ),
                        child: Column(
                          children: [
                            // Profile Image (non-editable)
                            _buildProfileImage(),
                            const SizedBox(height: 16),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                specialization,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Content ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(horizontalPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),

                                // ── Professional Info ────────────────────
                                _SectionHeader(
                                  title: 'Professional Information',
                                  isEditing: _isEditing,
                                  onEdit: () {
                                    if (_isEditing) {
                                      _saveProfile();
                                    } else {
                                      setState(() => _isEditing = true);
                                    }
                                  },
                                  isSaving: _isSaving,
                                ),
                                const SizedBox(height: 12),
                                _Card(
                                  child: Column(
                                    children: [
                                      _ProfileField(
                                        label: 'Full Name',
                                        controller: _nameCtrl,
                                        isEditing: _isEditing,
                                        icon: Icons.person_outline,
                                      ),
                                      const _HDivider(),
                                      _ProfileField(
                                        label: 'Specialization',
                                        controller: _specializationCtrl,
                                        isEditing: _isEditing,
                                        icon: Icons.medical_services_outlined,
                                        hint: 'e.g. General Practice',
                                      ),
                                      const _HDivider(),
                                      _ProfileField(
                                        label: 'License Number',
                                        controller: _licenseCtrl,
                                        isEditing: _isEditing,
                                        icon: Icons.badge_outlined,
                                        hint: 'e.g. LIC-001',
                                      ),
                                      const _HDivider(),
                                      _ProfileField(
                                        label: 'Working Hours',
                                        controller: _workingHoursCtrl,
                                        isEditing: _isEditing,
                                        icon: Icons.access_time_outlined,
                                        hint: 'e.g. 09:00 - 17:00',
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ── Account ───────────────────────────
                                const _SectionHeader(title: 'Account'),
                                const SizedBox(height: 12),
                                _Card(
                                  child: Column(
                                    children: [
                                      _InfoRow(
                                        icon: Icons.email_outlined,
                                        label: 'Email',
                                        value: email,
                                      ),
                                      const _HDivider(),
                                      const _InfoRow(
                                        icon: Icons.shield_outlined,
                                        label: 'Role',
                                        value: 'Doctor',
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ── Quick Actions ───────────────────────
                                const _SectionHeader(title: 'Quick Actions'),
                                const SizedBox(height: 12),
                                _Card(
                                  child: Column(
                                    children: [
                                      _ActionTile(
                                        icon: Icons.settings_outlined,
                                        color: AppColors.textSecondary,
                                        label: 'Settings',
                                        subtitle:
                                            'App preferences & notifications',
                                        onTap: () => _showSettingsDialog(),
                                      ),
                                      const _HDivider(),
                                      _ActionTile(
                                        icon: Icons.help_outline_rounded,
                                        color: AppColors.info,
                                        label: 'Help & Support',
                                        subtitle: 'Get help or report issues',
                                        onTap: () => _showHelpDialog(),
                                      ),
                                      const _HDivider(),
                                      _ActionTile(
                                        icon: Icons.info_outline_rounded,
                                        color: AppColors.success,
                                        label: 'About',
                                        subtitle: 'App version & info',
                                        onTap: () => _showAboutDialog(),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // ── Logout ────────────────────────────
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: _logout,
                                    icon: const Icon(
                                      Icons.logout,
                                      color: AppColors.error,
                                    ),
                                    label: const Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.error,
                                        width: 1.5,
                                      ),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: AppRadius.mdAll,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isEditing;
  final VoidCallback? onEdit;
  final bool isSaving;

  const _SectionHeader({
    required this.title,
    this.isEditing = false,
    this.onEdit,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (onEdit != null)
          GestureDetector(
            onTap: isSaving ? null : onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isEditing
                    ? AppColors.success
                    : AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSaving)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      isEditing ? Icons.check : Icons.edit,
                      size: 14,
                      color: isEditing ? Colors.white : AppColors.primary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isSaving ? 'Saving...' : (isEditing ? 'Save' : 'Edit'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isEditing ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.surfaceMuted),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(borderRadius: AppRadius.lgAll, child: child),
    );
  }
}

// ── Profile Field ─────────────────────────────────────────────────────────────

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final IconData icon;
  final String? hint;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.isEditing,
    required this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                if (isEditing)
                  TextField(
                    controller: controller,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    controller.text.isEmpty
                        ? (hint ?? 'Not set')
                        : controller.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: controller.text.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.successTint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Tile ─────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings Tile ───────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (onTap != null && trailing == null)
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Divider ──────────────────────────────────────────────────────────────────

class _HDivider extends StatelessWidget {
  const _HDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 76, endIndent: 16);
  }
}
