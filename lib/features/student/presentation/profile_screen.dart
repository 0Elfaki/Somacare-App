import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;

  // Nullable: null means the student has never recorded this vital, and
  // we must not show (or silently persist) a fabricated placeholder value
  // in its place. _PickerRow already renders an empty value as '—'.
  int? _height;
  int? _weight;
  String? _bloodType;
  int? _systolic;
  int? _diastolic;

  // ── Settings state ──
  bool _notificationsEnabled = true;

  final _allergiesCtrl = TextEditingController();

  static const _bloodTypes = [
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _allergiesCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select(
            'full_name,school,height,weight,blood_type,blood_pressure,allergies',
          )
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _profile = data;
          _height = int.tryParse(data?['height']?.toString() ?? '');
          _weight = int.tryParse(data?['weight']?.toString() ?? '');
          _bloodType = data?['blood_type'] as String?;
          final bp = data?['blood_pressure']?.toString();
          if (bp != null && bp.contains('/')) {
            final parts = bp.split('/');
            _systolic = int.tryParse(parts[0]);
            _diastolic = int.tryParse(parts.length > 1 ? parts[1] : '');
          } else {
            _systolic = null;
            _diastolic = null;
          }
          _allergiesCtrl.text = data?['allergies'] as String? ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      // Only write vitals the student has actually set via a picker (or
      // that were already on file) — never a fabricated placeholder
      // value for a field they never touched.
      final updates = <String, dynamic>{
        'id': userId,
        'allergies': _allergiesCtrl.text.trim(),
      };
      if (_height != null) updates['height'] = _height.toString();
      if (_weight != null) updates['weight'] = _weight.toString();
      if (_bloodType != null) updates['blood_type'] = _bloodType;
      if (_systolic != null && _diastolic != null) {
        updates['blood_pressure'] = '$_systolic/$_diastolic';
      }
      await Supabase.instance.client.from('profiles').upsert(updates);
      if (mounted) {
        setState(() => _isEditing = false);
        showAppSnack(
          context,
          'Profile updated successfully!',
          tone: AppStatusTone.success,
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          userFriendlyErrorMessage(
            e,
            defaultMessage: 'Unable to save profile changes. Please try again.',
          ),
          tone: AppStatusTone.danger,
        );
      }
    }
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  void _pickHeight() {
    int temp = _height ?? 170;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickerSheet(
        title: 'Select Height (cm)',
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: temp - 100,
          ),
          itemExtent: 40,
          onSelectedItemChanged: (i) => temp = i + 100,
          children: List.generate(
            121,
            (i) => Center(
              child: Text(
                '${i + 100} cm',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
        onDone: () => setState(() => _height = temp),
      ),
    );
  }

  void _pickWeight() {
    int temp = _weight ?? 70;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickerSheet(
        title: 'Select Weight (kg)',
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(initialItem: temp - 30),
          itemExtent: 40,
          onSelectedItemChanged: (i) => temp = i + 30,
          children: List.generate(
            171,
            (i) => Center(
              child: Text('${i + 30} kg', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
        onDone: () => setState(() => _weight = temp),
      ),
    );
  }

  void _pickBloodType() {
    String temp = _bloodType ?? _bloodTypes.first;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickerSheet(
        title: 'Select Blood Type',
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: _bloodTypes
                .indexOf(temp)
                .clamp(0, _bloodTypes.length - 1),
          ),
          itemExtent: 44,
          onSelectedItemChanged: (i) => temp = _bloodTypes[i],
          children: _bloodTypes
              .map(
                (t) => Center(
                  child: Text(t, style: const TextStyle(fontSize: 20)),
                ),
              )
              .toList(),
        ),
        onDone: () => setState(() => _bloodType = temp),
      ),
    );
  }

  void _pickBP() {
    int tempS = _systolic ?? 120;
    int tempD = _diastolic ?? 80;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => SizedBox(
          height: 320,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Blood Pressure (mmHg)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _systolic = tempS;
                          _diastolic = tempD;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Systolic',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Diastolic',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: (tempS - 60).clamp(0, 140),
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) =>
                            setModal(() => tempS = i + 60),
                        children: List.generate(
                          141,
                          (i) => Center(
                            child: Text(
                              '${i + 60}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      '/',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: (tempD - 40).clamp(0, 90),
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) =>
                            setModal(() => tempD = i + 40),
                        children: List.generate(
                          91,
                          (i) => Center(
                            child: Text(
                              '${i + 40}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Payment Sheets ────────────────────────────────────────────────────────
  // Linking a payment method here isn't wired to anything real yet — there
  // is no backend table or gateway behind it. It used to collect a phone
  // number (or, worse, a full card number + expiry + CVV) and then claim
  // success regardless, which is worse than doing nothing: it told the
  // student a payment method was on file when none was. This sheet says so
  // plainly instead, and collects nothing.
  void _showComingSoonPaymentSheet(
    BuildContext ctx,
    String title,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Saving payment methods here isn\'t available yet. You can '
              'still pay with MTN or Airtel Money directly when you book an '
              'appointment.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Change Password ───────────────────────────────────────────────────────
  void _showChangePasswordSheet(BuildContext ctx) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Password',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New Password',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: AppColors.warning, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(password: ctrl.text.trim()),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            userFriendlyErrorMessage(
                              e,
                              defaultMessage:
                                  'Could not update your password. Please try again.',
                            ),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Update Password',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        // The sheet owns this controller; release it when the sheet
        // closes rather than leaking one per open.
        .whenComplete(ctrl.dispose);
  }

  // ── About SOMA CARE ────────────────────────────────────────────────────────
  void _showAboutSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.success],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'SOMA CARE',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 2.0.0',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your trusted telemedicine companion for student health and wellness.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              '© 2026 SOMACARE',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/onboarding');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = _profile?['full_name'] as String? ?? user?.email ?? 'Student';
    final email = user?.email ?? '';
    final school = _profile?['school'] as String? ?? 'University';

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;
                final maxContentWidth = isTablet ? 600.0 : double.infinity;

                return CustomScrollView(
                  slivers: [
                    // ── Header ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.success],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 40 : 20,
                          MediaQuery.of(context).padding.top + 16,
                          isTablet ? 40 : 20,
                          32,
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 52,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: AppShadows.sm,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                school,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Personal Info Header ─────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 24 : 16,
                          24,
                          isTablet ? 24 : 16,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_isEditing) {
                                  _saveProfile();
                                } else {
                                  setState(() => _isEditing = true);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _isEditing
                                      ? AppColors.success
                                      : AppColors.primaryLight.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isEditing ? Icons.check : Icons.edit,
                                      size: 16,
                                      color: _isEditing
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isEditing ? 'Save' : 'Edit',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _isEditing
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Info Fields ──────────────────────────
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: _Card(
                            child: Column(
                              children: [
                                _PickerRow(
                                  icon: Icons.height,
                                  label: 'Height',
                                  value: _height != null ? '$_height cm' : '',
                                  editing: _isEditing,
                                  onTap: _pickHeight,
                                ),
                                const _HDivider(),
                                _PickerRow(
                                  icon: Icons.monitor_weight_outlined,
                                  label: 'Weight',
                                  value: _weight != null ? '$_weight kg' : '',
                                  editing: _isEditing,
                                  onTap: _pickWeight,
                                ),
                                const _HDivider(),
                                _PickerRow(
                                  icon: Icons.bloodtype_outlined,
                                  label: 'Blood Type',
                                  value: _bloodType ?? '',
                                  editing: _isEditing,
                                  onTap: _pickBloodType,
                                ),
                                const _HDivider(),
                                _PickerRow(
                                  icon: Icons.favorite_outline,
                                  label: 'Blood Pressure',
                                  value: (_systolic != null && _diastolic != null)
                                      ? '$_systolic / $_diastolic mmHg'
                                      : '',
                                  editing: _isEditing,
                                  onTap: _pickBP,
                                ),
                                const _HDivider(),
                                _TypedRow(
                                  icon: Icons.warning_amber_outlined,
                                  label: 'Allergies',
                                  ctrl: _allergiesCtrl,
                                  editing: _isEditing,
                                  hint: 'e.g. Penicillin',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Quick Access ─────────────────────────
                    _SectionLabel('Quick Access', isTablet: isTablet),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: _Card(
                            child: Column(
                              children: [
                                _MenuTile(
                                  icon: Icons.calendar_today_outlined,
                                  color: AppColors.info,
                                  label: 'My Appointments',
                                  onTap: () => context.go('/my-appointments'),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.inventory_2_outlined,
                                  color: AppColors.accent,
                                  label: 'My Prescriptions',
                                  onTap: () => context.push('/prescriptions'),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.folder_open_outlined,
                                  color: AppColors.warning,
                                  label: 'My Medical History',
                                  onTap: () => context.push('/medical-history'),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.medication_outlined,
                                  color: AppColors.success,
                                  label: 'My Medications',
                                  onTap: () => context.push('/my-medications'),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.description_outlined,
                                  color: AppColors.success,
                                  label: 'My Records',
                                  onTap: () => context.push('/records'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Payment Methods ───────────────────────
                    _SectionLabel('Payment Methods', isTablet: isTablet),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: _Card(
                            child: Column(
                              children: [
                                _PaymentTile(
                                  icon: Icons.phone_android,
                                  name: 'MTN Mobile Money',
                                  subtitle: 'Link your MTN MoMo number',
                                  color: PaymentBrandColors.mpesaYellow,
                                  onTap: () => _showComingSoonPaymentSheet(
                                    context,
                                    'MTN Mobile Money',
                                    Icons.phone_android,
                                    PaymentBrandColors.mpesaAmber,
                                  ),
                                ),
                                const _HDivider(),
                                _PaymentTile(
                                  icon: Icons.phone_android,
                                  name: 'Airtel Money',
                                  subtitle: 'Link your Airtel number',
                                  color: AppColors.error,
                                  onTap: () => _showComingSoonPaymentSheet(
                                    context,
                                    'Airtel Money',
                                    Icons.phone_android,
                                    AppColors.error,
                                  ),
                                ),
                                const _HDivider(),
                                _PaymentTile(
                                  icon: Icons.credit_card,
                                  name: 'Visa / Mastercard',
                                  subtitle: 'Add a debit or credit card',
                                  color: AppColors.info,
                                  onTap: () => _showComingSoonPaymentSheet(
                                    context,
                                    'Visa / Mastercard',
                                    Icons.credit_card,
                                    AppColors.info,
                                  ),
                                ),
                                const _HDivider(),
                                _PaymentTile(
                                  icon: Icons.account_balance,
                                  name: 'Bank Transfer',
                                  subtitle: 'Stanbic · DFCU · Centenary Bank',
                                  color: AppColors.success,
                                  onTap: () => _showComingSoonPaymentSheet(
                                    context,
                                    'Bank Transfer',
                                    Icons.account_balance,
                                    AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Settings ──────────────────────────────
                    _SectionLabel('Settings', isTablet: isTablet),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: _Card(
                            child: Column(
                              children: [
                                _SettingsTile(
                                  icon: Icons.notifications_outlined,
                                  label: 'Notifications',
                                  color: AppColors.info,
                                  trailing: Switch(
                                    value: _notificationsEnabled,
                                    activeThumbColor: AppColors.info,
                                    onChanged: (v) => setState(
                                      () => _notificationsEnabled = v,
                                    ),
                                  ),
                                ),
                                const _HDivider(),
                                const _SettingsTile(
                                  icon: Icons.dark_mode_outlined,
                                  label: 'Dark Mode',
                                  subtitle: 'Coming soon',
                                  color: AppColors.success,
                                  trailing: Switch(
                                    value: false,
                                    onChanged: null,
                                    activeThumbColor: AppColors.success,
                                  ),
                                ),
                                const _HDivider(),
                                const _SettingsTile(
                                  icon: Icons.language_outlined,
                                  label: 'Language',
                                  subtitle:
                                      'English is the only language available right now',
                                  color: AppColors.success,
                                  trailing: Text(
                                    'English',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                const _HDivider(),
                                _SettingsTile(
                                  icon: Icons.lock_outline,
                                  label: 'Change Password',
                                  color: AppColors.warning,
                                  onTap: () =>
                                      _showChangePasswordSheet(context),
                                ),
                                const _HDivider(),
                                _SettingsTile(
                                  icon: Icons.info_outline,
                                  label: 'About SOMA CARE',
                                  color: AppColors.info,
                                  labelColor: AppColors.info,
                                  onTap: () => _showAboutSheet(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Help & Support ────────────────────────
                    _SectionLabel('Help & Support', isTablet: isTablet),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: _Card(
                            child: Column(
                              children: [
                                _MenuTile(
                                  icon: Icons.chat_bubble_outline,
                                  color: AppColors.info,
                                  label: 'Live Chat Support',
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text('Coming soon'),
                                        ),
                                      ),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.help_outline,
                                  color: AppColors.success,
                                  label: 'FAQs',
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text('Coming soon'),
                                        ),
                                      ),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.privacy_tip_outlined,
                                  color: AppColors.success,
                                  label: 'Privacy Policy',
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text('Coming soon'),
                                        ),
                                      ),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.description_outlined,
                                  color: AppColors.warning,
                                  label: 'Terms of Service',
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text('Coming soon'),
                                        ),
                                      ),
                                ),
                                const _HDivider(),
                                _MenuTile(
                                  icon: Icons.info_outline,
                                  color: AppColors.textMuted,
                                  label: 'App Version 2.0.0',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Sign Out ─────────────────────────────
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 24 : 16,
                              24,
                              isTablet ? 24 : 16,
                              32,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _logout,
                                icon: const Icon(
                                  Icons.logout,
                                  color: AppColors.error,
                                ),
                                label: const Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w800,
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

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends SliverToBoxAdapter {
  final String text;
  final bool isTablet;

  _SectionLabel(this.text, {this.isTablet = false})
    : super(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            24,
            isTablet ? 24 : 16,
            0,
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
}

// ── Card Wrapper ──────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

// ── Picker Row ────────────────────────────────────────────────────────────────

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool editing;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.editing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: editing ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
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
                    const SizedBox(height: 2),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: editing
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (editing)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typed Row ─────────────────────────────────────────────────────────────────

class _TypedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final bool editing;
  final String hint;

  const _TypedRow({
    required this.icon,
    required this.label,
    required this.ctrl,
    required this.editing,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warningTint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.warning),
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
                const SizedBox(height: 4),
                if (editing)
                  TextField(
                    controller: ctrl,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary),
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
                    ctrl.text.isEmpty ? '—' : ctrl.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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

// ── Picker Sheet ──────────────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onDone;

  const _PickerSheet({
    required this.title,
    required this.child,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    onDone();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Menu Tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.label,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
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

// ── Payment Tile ──────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.color,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
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

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    this.trailing,
    this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
              if (onTap != null && trailing == null)
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

// ── Divider ──────────────────────────────────────────────────────────────────

class _HDivider extends StatelessWidget {
  const _HDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 76, endIndent: 16);
  }
}
