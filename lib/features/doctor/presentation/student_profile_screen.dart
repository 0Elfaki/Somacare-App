import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'doctor_medical_history_management_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../../student/data/lab_result_model.dart';
import '../../student/data/lab_result_repository.dart';

class StudentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> extra;

  const StudentProfileScreen({super.key, required this.extra});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _pastAppointments = [];
  List<Map<String, dynamic>> _activePrescriptions = [];
  List<LabResult> _labResults = [];
  bool _isLoading = true;

  String get _studentId => (widget.extra['studentId'] as String?) ?? '';
  String get _studentName =>
      (widget.extra['studentName'] as String?) ?? 'Student';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadLabResults() async {
    if (_studentId.isEmpty) return;
    final results = await LabResultRepository.instance.fetchForStudent(
      _studentId,
    );
    if (mounted) setState(() => _labResults = results);
  }

  Future<void> _addLabResult() async {
    final formKey = GlobalKey<FormState>();
    final testCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final lowCtrl = TextEditingController();
    final highCtrl = TextEditingController();
    LabResultStatus status = LabResultStatus.normal;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add lab result',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: testCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Test name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: valueCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Value'),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? 'Number' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: unitCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: lowCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Range low',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: highCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Range high',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<LabResultStatus>(
                  initialValue: status,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: LabResultStatus.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => status = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final ok = await LabResultRepository.instance.add(
                        LabResult(
                          id: '',
                          studentId: _studentId,
                          doctorId:
                              Supabase.instance.client.auth.currentUser?.id,
                          testName: testCtrl.text.trim(),
                          value: double.parse(valueCtrl.text.trim()),
                          unit: unitCtrl.text.trim().isEmpty
                              ? null
                              : unitCtrl.text.trim(),
                          referenceLow: double.tryParse(lowCtrl.text.trim()),
                          referenceHigh: double.tryParse(highCtrl.text.trim()),
                          status: status,
                          testDate: DateTime.now(),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx, ok);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // The five controllers above live exactly as long as the sheet. Without
    // this they leaked on every open — each one holds a listener list and a
    // native text-input connection.
    for (final c in [testCtrl, valueCtrl, unitCtrl, lowCtrl, highCtrl]) {
      c.dispose();
    }

    if (saved == true) {
      await _loadLabResults();
      if (mounted) {
        showAppSnack(
          context,
          'Lab result added.',
          tone: AppStatusTone.success,
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_studentId.isEmpty) return;

      // Load student profile
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _studentId)
          .maybeSingle();

      // Load past appointments with this doctor
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final appointmentsData = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('student_id', _studentId)
          .eq('doctor_id', userId)
          .order('date', ascending: false)
          .limit(10);

      // Load active prescriptions
      final prescriptionsData = await Supabase.instance.client
          .from('prescriptions')
          .select()
          .eq('student_id', _studentId)
          .eq('status', 'active')
          .order('date_prescribed', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profileData;
          _pastAppointments = List<Map<String, dynamic>>.from(appointmentsData);
          _activePrescriptions = List<Map<String, dynamic>>.from(
            prescriptionsData,
          );
          _isLoading = false;
        });
      }
      unawaited(_loadLabResults());
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

  double _bmi(int height, int weight) {
    if (height <= 0) return 0;
    final h = height / 100;
    return weight / (h * h);
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.info;
    if (bmi < 25) return AppColors.primary;
    if (bmi < 30) return AppColors.warningDark;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (_profile?['full_name'] as String?) ?? _studentName;
    final school = (_profile?['school'] as String?) ?? '';
    // Vitals are shown only when actually on file — a doctor seeing a
    // number here has to be able to trust it's the student's real data,
    // not a plausible-looking placeholder.
    final height = int.tryParse((_profile?['height'] ?? '').toString());
    final weight = int.tryParse((_profile?['weight'] ?? '').toString());
    final bloodTypeRaw = _profile?['blood_type'] as String?;
    final bloodType =
        (bloodTypeRaw != null && bloodTypeRaw.isNotEmpty) ? bloodTypeRaw : null;
    final bpRaw = _profile?['blood_pressure'] as String?;
    final bp = (bpRaw != null && bpRaw.isNotEmpty) ? bpRaw : null;
    final allergies = (_profile?['allergies'] as String?) ?? '';
    final bmiVal = (height != null && weight != null)
        ? _bmi(height, weight)
        : null;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          title: Text(fullName, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadData,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Labs'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : TabBarView(
                children: [
                  // Tab 1: Overview
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Patient Header ────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.info],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (school.isNotEmpty)
                                      Text(
                                        school,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Vitals ────────────────────────────
                        const _SectionHeader(title: 'Vitals'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _VitalCard(
                                label: 'Height',
                                value: height != null ? '$height cm' : null,
                                icon: Icons.height,
                                color: AppColors.info,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _VitalCard(
                                label: 'Weight',
                                value: weight != null ? '$weight kg' : null,
                                icon: Icons.monitor_weight_outlined,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _VitalCard(
                                label: 'BMI',
                                value: bmiVal != null
                                    ? '${bmiVal.toStringAsFixed(1)} (${_bmiCategory(bmiVal)})'
                                    : null,
                                icon: Icons.analytics_outlined,
                                color: bmiVal != null
                                    ? _bmiColor(bmiVal)
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _VitalCard(
                                label: 'Blood Pressure',
                                value: bp,
                                icon: Icons.favorite_outline,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _VitalCard(
                          label: 'Blood Type',
                          value: bloodType,
                          icon: Icons.bloodtype_outlined,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 20),

                        // ── Allergies ─────────────────────────
                        const _SectionHeader(title: 'Allergies'),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: allergies.isEmpty
                                ? AppColors.successSurface
                                : AppColors.warningSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: allergies.isEmpty
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : const Color(
                                      0xFFD97706,
                                    ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                allergies.isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_outlined,
                                color: allergies.isEmpty
                                    ? AppColors.primary
                                    : AppColors.warningDark,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  allergies.isEmpty
                                      ? 'No known allergies'
                                      : allergies,
                                  style: TextStyle(
                                    color: allergies.isEmpty
                                        ? AppColors.primary
                                        : AppColors.warningDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Active Prescriptions ──────────────
                        if (_activePrescriptions.isNotEmpty) ...[
                          const _SectionHeader(title: 'Active Prescriptions'),
                          const SizedBox(height: 10),
                          ..._activePrescriptions.map(
                            (rx) => _PrescriptionChip(prescription: rx),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Past Appointments ─────────────────
                        const _SectionHeader(title: 'Past Appointments'),
                        const SizedBox(height: 10),
                        if (_pastAppointments.isEmpty)
                          const _EmptyState(
                            icon: Icons.event_available_outlined,
                            message: 'No past appointments with you',
                          )
                        else
                          ..._pastAppointments.map(
                            (appt) => _PastAppointmentRow(appointment: appt),
                          ),
                        const SizedBox(height: 20),

                        // ── Medical History Button ─────────────────
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Tab 2: Labs
                  _LabsTab(results: _labResults, onAdd: _addLabResult),
                  // Tab 3: Medical History
                  DoctorMedicalHistoryManagementScreen(
                    studentId: _studentId,
                    isEmbedded: true,
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Labs Tab ──────────────────────────────────────────────────────────────────

class _LabsTab extends StatelessWidget {
  final List<LabResult> results;
  final VoidCallback onAdd;

  const _LabsTab({required this.results, required this.onAdd});

  Color _statusColor(LabResultStatus s) => switch (s) {
    LabResultStatus.normal => AppColors.primary,
    LabResultStatus.abnormal => AppColors.warningDark,
    LabResultStatus.critical => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add lab result'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: results.isEmpty
                ? const _EmptyState(
                    icon: Icons.science_outlined,
                    message: 'No lab results on file',
                  )
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      final color = _statusColor(r.status);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.testName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${r.testDate.toIso8601String().split('T').first} · ${r.rangeLabel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${r.value}${r.unit ?? ''}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Vital Card ────────────────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final Color color;

  const _VitalCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final displayColor = hasValue ? color : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: displayColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: displayColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: displayColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  hasValue ? value! : 'Not recorded',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasValue ? FontWeight.w800 : FontWeight.w600,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    color: displayColor,
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

// ── Prescription Chip ─────────────────────────────────────────────────────────

class _PrescriptionChip extends StatelessWidget {
  final Map<String, dynamic> prescription;
  const _PrescriptionChip({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final name = (prescription['medication_name'] as String?) ?? '';
    final dosage = (prescription['dosage'] as String?) ?? '';
    final frequency = (prescription['frequency'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medication_outlined,
            color: AppColors.primaryLight,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  '$dosage · $frequency',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

// ── Past Appointment Row ──────────────────────────────────────────────────────

class _PastAppointmentRow extends StatelessWidget {
  final Map<String, dynamic> appointment;
  const _PastAppointmentRow({required this.appointment});

  static Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.primary;
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warningDark;
      case 'cancelled':
      case 'rejected':
      case 'declined':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  static Color _statusBg(String status) {
    switch (status) {
      case 'completed':
      case 'confirmed':
        return AppColors.successSurface;
      case 'pending':
        return AppColors.warningSurface;
      case 'cancelled':
      case 'rejected':
      case 'declined':
        return AppColors.errorSurface;
      default:
        return AppColors.surfaceMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (appointment['date'] as String?) ?? '';
    final reason = (appointment['reason'] as String?) ?? '';
    final status = (appointment['status'] as String?) ?? '';
    final notes = (appointment['doctor_notes'] as String?) ?? '';
    final statusColor = _statusColor(status);
    final statusBg = _statusBg(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.isEmpty ? 'Unknown' : status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: $notes',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textStrong,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.borderStrong),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
