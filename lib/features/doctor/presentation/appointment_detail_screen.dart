import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Map<String, dynamic> _appointment;
  Map<String, dynamic>? _studentProfile;
  bool _isLoading = true;
  bool _isSaving = false;
  late final TextEditingController _notesCtrl;

  static const _statuses = ['pending', 'confirmed', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _appointment = Map<String, dynamic>.from(widget.appointment);
    _notesCtrl = TextEditingController(
      text: (_appointment['doctor_notes'] as String?) ?? '',
    );
    _loadStudentProfile();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudentProfile() async {
    setState(() => _isLoading = true);
    try {
      final studentId = _appointment['student_id'] as String?;
      if (studentId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', studentId)
            .maybeSingle();
        if (mounted) setState(() => _studentProfile = data);
      }
    } catch (_) {
      // Profile load failure is non-critical
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);
    try {
      final id = _appointment['id'] as String?;
      if (id == null || id.isEmpty) return;
      await Supabase.instance.client
          .from('appointments')
          .update({'doctor_notes': _notesCtrl.text.trim()})
          .eq('id', id);

      setState(() {
        _appointment['doctor_notes'] = _notesCtrl.text.trim();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save notes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmAndUpdateStatus(String newStatus) async {
    if (newStatus == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel this appointment?'),
          content: const Text(
            'The patient will be notified. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep appointment'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel appointment'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _updateStatus(newStatus);
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final id = _appointment['id'] as String?;
      if (id == null || id.isEmpty) return;
      await Supabase.instance.client
          .from('appointments')
          .update({'status': newStatus})
          .eq('id', id);

      setState(() => _appointment['status'] = newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  BloomBadgeStatus _badgeStatus(String status) {
    switch (status) {
      case 'confirmed':
        return BloomBadgeStatus.active;
      case 'pending':
        return BloomBadgeStatus.pending;
      case 'cancelled':
        return BloomBadgeStatus.danger;
      case 'completed':
        return BloomBadgeStatus.info;
      default:
        return BloomBadgeStatus.neutral;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.primaryLight;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_appointment['status'] as String?) ?? 'pending';
    final date = (_appointment['date'] as String?) ?? '';
    final time = (_appointment['time'] as String?) ?? '';
    final reason = (_appointment['reason'] as String?) ?? '';
    final isEmergency = _appointment['is_emergency'] == true;
    final appointmentId = (_appointment['id'] as String?) ?? '';
    final studentId = (_appointment['student_id'] as String?) ?? '';

    final studentName =
        (_studentProfile?['full_name'] as String?) ??
        (_appointment['student_name'] as String?) ??
        'Student';
    final school =
        (_studentProfile?['school'] as String?) ??
        (_appointment['school'] as String?) ??
        '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/doctor-dashboard');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              const BloomScreenHeader(title: 'Appointment'),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Patient card ──────────────────
                            BloomCard(
                              child: Row(
                                children: [
                                  const BloomAvatar(size: 36),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: BloomTextStyles.inter(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (school.isNotEmpty)
                                          Text(
                                            school,
                                            style: BloomTextStyles.inter(
                                              size: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  BloomStatusBadge(
                                    label: status,
                                    status: _badgeStatus(status),
                                  ),
                                ],
                              ),
                            ),
                            if (isEmergency) ...[
                              const SizedBox(height: 10),
                              const BloomTextBadge(
                                label: 'IMMEDIATE / EMERGENCY',
                                status: BloomBadgeStatus.danger,
                              ),
                            ],
                            if (studentId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => context.push(
                                    '/student-profile',
                                    extra: <String, dynamic>{
                                      'studentId': studentId,
                                      'studentName': studentName,
                                    },
                                  ),
                                  child: Text(
                                    'View full patient history →',
                                    style: BloomTextStyles.inter(
                                      size: 11.5,
                                      weight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const BloomSectionTitle('Visit details'),
                            BloomCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Date',
                                    value: date,
                                  ),
                                  const SizedBox(height: 10),
                                  _InfoRow(
                                    icon: Icons.access_time_outlined,
                                    label: 'Time',
                                    value: time,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: BloomDivider(),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Status',
                                        style: BloomTextStyles.inter(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      DropdownButton<String>(
                                        value: status,
                                        underline: const SizedBox(),
                                        dropdownColor: AppColors.surface,
                                        style: BloomTextStyles.inter(
                                          size: 12,
                                          weight: FontWeight.w700,
                                          color: _statusColor(status),
                                        ),
                                        items: _statuses
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(
                                                  s[0].toUpperCase() +
                                                      s.substring(1),
                                                  style: TextStyle(
                                                    color: _statusColor(s),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null && val != status) {
                                            _confirmAndUpdateStatus(val);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const BloomSectionTitle('Reason for visit'),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.cardAll,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: const BoxDecoration(
                                  borderRadius: AppRadius.cardAll,
                                  border: Border(
                                    left: BorderSide(
                                      color: AppColors.success,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  reason.isEmpty
                                      ? 'No reason provided.'
                                      : reason,
                                  style: BloomTextStyles.inter(
                                    size: 12.5,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const BloomSectionTitle('Doctor notes'),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.mdAll,
                                border: Border.all(color: AppColors.border),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: TextField(
                                controller: _notesCtrl,
                                maxLines: 4,
                                style: BloomTextStyles.inter(
                                  size: 12,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Add clinical notes, observations…',
                                  hintStyle: BloomTextStyles.inter(
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 140,
                                child: BloomButton(
                                  label: 'Save notes',
                                  height: 44,
                                  isLoading: _isSaving,
                                  onPressed: _isSaving ? null : _saveNotes,
                                ),
                              ),
                            ),

                            const BloomSectionTitle('Actions'),
                            if (status == 'pending' || status == 'confirmed')
                              _ActionTile(
                                icon: Icons.videocam_outlined,
                                label: 'Join Video Consultation',
                                subtitle: 'Start Agora video call with patient',
                                color: AppColors.primary,
                                onTap: () => context.push(
                                  '/doctor-consult',
                                  extra: <String, dynamic>{
                                    'appointmentId': appointmentId,
                                    'studentName': studentName,
                                  },
                                ),
                              ),
                            const SizedBox(height: 10),
                            _ActionTile(
                              icon: Icons.assignment_outlined,
                              label: 'Encounter (Vitals & Diagnosis)',
                              subtitle: 'Record vitals, diagnosis, follow-up',
                              color: AppColors.primaryLight,
                              onTap: () => context.push(
                                '/encounter-form',
                                extra: <String, dynamic>{
                                  'appointmentId': appointmentId,
                                  'studentId': studentId,
                                  'studentName': studentName,
                                  'reason': reason,
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ActionTile(
                              icon: Icons.description_outlined,
                              label: 'Write Prescription',
                              subtitle:
                                  'Issue medication prescription for patient',
                              color: AppColors.success,
                              onTap: () => context.push(
                                '/prescription-writer',
                                extra: <String, dynamic>{
                                  'studentId': studentId,
                                  'studentName': studentName,
                                  'appointmentId': appointmentId,
                                },
                              ),
                            ),
                            if (studentId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _ActionTile(
                                icon: Icons.person_outline,
                                label: 'View Patient Profile',
                                subtitle:
                                    'See vitals, allergies, and medical history',
                                color: AppColors.warning,
                                onTap: () => context.push(
                                  '/student-profile',
                                  extra: <String, dynamic>{
                                    'studentId': studentId,
                                    'studentName': studentName,
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: BloomTextStyles.inter(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: BloomTextStyles.inter(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action Tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.tileAll,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: BloomTextStyles.inter(
                      size: 13,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: BloomTextStyles.inter(
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
