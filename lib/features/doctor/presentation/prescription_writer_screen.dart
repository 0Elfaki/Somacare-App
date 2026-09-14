import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

class PrescriptionWriterScreen extends StatefulWidget {
  final Map<String, dynamic> extra;

  const PrescriptionWriterScreen({super.key, this.extra = const {}});

  @override
  State<PrescriptionWriterScreen> createState() =>
      _PrescriptionWriterScreenState();
}

class _PrescriptionWriterScreenState extends State<PrescriptionWriterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicationCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _pharmacyCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  String _frequency = 'Once daily';
  int _durationDays = 7;
  int _refills = 0;
  bool _isLoading = false;
  String _doctorName = '';

  static const _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'Every 8 hours',
    'Every 12 hours',
    'As needed',
    'Weekly',
  ];

  static const _durations = [3, 5, 7, 10, 14, 21, 30, 60, 90];

  String get _studentId {
    try {
      final value = widget.extra['studentId'];
      return value?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  String get _studentName {
    try {
      final value = widget.extra['studentName'];
      return value?.toString() ?? 'Patient';
    } catch (e) {
      return 'Patient';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDoctorName();
  }

  @override
  void dispose() {
    _medicationCtrl.dispose();
    _dosageCtrl.dispose();
    _pharmacyCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorName() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _doctorName = (profile?['full_name'] as String?) ?? '';
        });
      }
    } catch (e) {
      // Silently handle error - doctor name is optional
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patient selected. Please go back and try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: _durationDays));

      // First, create the prescription
      await Supabase.instance.client.from('prescriptions').insert({
        'student_id': _studentId,
        'doctor_id': userId,
        'medication_name': _medicationCtrl.text.trim(),
        'dosage': _dosageCtrl.text.trim(),
        'frequency': _frequency,
        'prescribing_doctor': 'Dr. $_doctorName',
        'pharmacy': _pharmacyCtrl.text.trim().isEmpty
            ? null
            : _pharmacyCtrl.text.trim(),
        'date_prescribed': now.toIso8601String().split('T').first,
        'expiry_date': expiryDate.toIso8601String().split('T').first,
        'status': 'active',
        'refills_remaining': _refills,
        'refills_total': _refills,
        'instructions': _instructionsCtrl.text.trim().isEmpty
            ? null
            : _instructionsCtrl.text.trim(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Try to add to medical history (optional - table may not exist yet)
      try {
        final medicationEntry =
            '''
Prescription: ${_medicationCtrl.text.trim()}
Dosage: ${_dosageCtrl.text.trim()}
Frequency: $_frequency
Duration: $_durationDays days
Doctor: Dr. $_doctorName
Prescribed: ${now.toIso8601String().split('T').first}
''';

        final existingHistory = await Supabase.instance.client
            .from('medical_histories')
            .select('current_medications')
            .eq('student_id', _studentId)
            .maybeSingle();

        String existingMeds = '';
        if (existingHistory != null &&
            existingHistory['current_medications'] != null) {
          existingMeds = existingHistory['current_medications'] as String;
        }

        final updatedMeds = existingMeds.isEmpty
            ? medicationEntry
            : '$existingMeds\n\n---\n\n$medicationEntry';

        await Supabase.instance.client.from('medical_histories').upsert({
          'student_id': _studentId,
          'current_medications': updatedMeds,
          'updated_at': now.toIso8601String(),
        }, onConflict: 'student_id');
      } catch (_) {
        // medical_histories table may not exist yet - that's OK
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription issued for $_studentName'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to issue prescription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const BloomScreenHeader(title: 'New prescription'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BloomCard(
                        child: Row(
                          children: [
                            const BloomAvatar(size: 32),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prescribing for',
                                  style: BloomTextStyles.inter(
                                    size: 10.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  _studentName,
                                  style: BloomTextStyles.inter(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const _FieldLabel('Medication'),
                      const SizedBox(height: 6),
                      _BloomFormField(
                        controller: _medicationCtrl,
                        hint: 'e.g. Paracetamol 500mg',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Dosage + Frequency side by side (spec screen 29)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Dosage'),
                                const SizedBox(height: 6),
                                _BloomFormField(
                                  controller: _dosageCtrl,
                                  hint: '2 tabs',
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Frequency'),
                                const SizedBox(height: 6),
                                _BloomDropdown<String>(
                                  value: _frequency,
                                  items: _frequencies,
                                  labelOf: (f) => f,
                                  onChanged: (val) =>
                                      setState(() => _frequency = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const _FieldLabel('Duration'),
                      const SizedBox(height: 6),
                      _BloomDropdown<int>(
                        value: _durationDays,
                        items: _durations,
                        labelOf: (d) => '$d days',
                        onChanged: (val) => setState(() => _durationDays = val),
                      ),
                      const SizedBox(height: 14),

                      const _FieldLabel('Refills allowed'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StepperButton(
                            icon: Icons.remove,
                            onTap: () {
                              if (_refills > 0) setState(() => _refills--);
                            },
                          ),
                          Container(
                            width: 52,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: BloomMonoText('$_refills', size: 15),
                          ),
                          _StepperButton(
                            icon: Icons.add,
                            onTap: () {
                              if (_refills < 10) setState(() => _refills++);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const _FieldLabel('Pharmacy (optional)'),
                      const SizedBox(height: 6),
                      _BloomFormField(
                        controller: _pharmacyCtrl,
                        hint: 'e.g. Campus Pharmacy',
                      ),
                      const SizedBox(height: 14),

                      const _FieldLabel('Special instructions (optional)'),
                      const SizedBox(height: 6),
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
                        child: TextFormField(
                          controller: _instructionsCtrl,
                          maxLines: 3,
                          style: BloomTextStyles.inter(
                            size: 12,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Take with food, avoid alcohol…',
                            hintStyle: BloomTextStyles.inter(
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: BloomButton(
                label: 'Submit prescription',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: BloomTextStyles.inter(
        size: 10,
        weight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.04,
      ),
    );
  }
}

// ── Form Field ────────────────────────────────────────────────────────────────

class _BloomFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _BloomFormField({
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: BloomTextStyles.inter(
          size: 12,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: BloomTextStyles.inter(
            size: 12,
            color: AppColors.textMuted,
          ),
          errorStyle: BloomTextStyles.inter(size: 10, color: AppColors.error),
        ),
      ),
    );
  }
}

class _BloomDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _BloomDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: BloomTextStyles.inter(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(labelOf(i))))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
