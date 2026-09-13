import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

/// Spec screen 28 — Encounter Form.
///
/// There is no dedicated `encounters` table in the current schema, so the
/// structured vitals/diagnosis are serialized into the existing
/// `appointments.doctor_notes` column (the same column the free-text notes
/// field on Appointment Detail writes to) rather than requiring a migration.
class EncounterFormScreen extends StatefulWidget {
  final String appointmentId;
  final String studentName;
  final String? initialReason;

  const EncounterFormScreen({
    super.key,
    required this.appointmentId,
    required this.studentName,
    this.initialReason,
  });

  @override
  State<EncounterFormScreen> createState() => _EncounterFormScreenState();
}

class _EncounterFormScreenState extends State<EncounterFormScreen> {
  late final _complaintCtrl = TextEditingController(
    text: widget.initialReason ?? '',
  );
  final _tempCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  bool _followUpRequired = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _complaintCtrl.dispose();
    _tempCtrl.dispose();
    _bpCtrl.dispose();
    _hrCtrl.dispose();
    _diagnosisCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.appointmentId.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final buf = StringBuffer()
      ..writeln('Encounter')
      ..writeln('Chief complaint: ${_complaintCtrl.text.trim()}')
      ..writeln(
        'Vitals: ${_tempCtrl.text.trim().isEmpty ? '—' : _tempCtrl.text.trim()} · '
        '${_bpCtrl.text.trim().isEmpty ? '—' : _bpCtrl.text.trim()} · '
        '${_hrCtrl.text.trim().isEmpty ? '—' : _hrCtrl.text.trim()}',
      )
      ..writeln('Diagnosis: ${_diagnosisCtrl.text.trim()}')
      ..writeln('Follow-up required: ${_followUpRequired ? 'Yes' : 'No'}');

    try {
      final existing = await Supabase.instance.client
          .from('appointments')
          .select('doctor_notes')
          .eq('id', widget.appointmentId)
          .maybeSingle();
      final prior = (existing?['doctor_notes'] as String?)?.trim() ?? '';

      final combined = prior.isEmpty
          ? buf.toString().trim()
          : '$prior\n\n${buf.toString().trim()}';

      await Supabase.instance.client
          .from('appointments')
          .update({'doctor_notes': combined})
          .eq('id', widget.appointmentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encounter saved'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save encounter: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            BloomScreenHeader(title: 'Encounter: ${widget.studentName}'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Chief complaint'),
                    _BloomTextArea(controller: _complaintCtrl, minLines: 2),
                    const SizedBox(height: 14),
                    const _FieldLabel('Vitals'),
                    Row(
                      children: [
                        Expanded(
                          child: _MonoField(
                            controller: _tempCtrl,
                            hint: '37.0°C',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MonoField(
                            controller: _bpCtrl,
                            hint: '110/70',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MonoField(
                            controller: _hrCtrl,
                            hint: '76 bpm',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Diagnosis'),
                    _BloomTextArea(controller: _diagnosisCtrl, minLines: 3),
                    const SizedBox(height: 14),
                    BloomCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Follow-up required',
                              style: BloomTextStyles.inter(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          BloomToggle(
                            value: _followUpRequired,
                            onChanged: (v) =>
                                setState(() => _followUpRequired = v),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                label: 'Save encounter',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label.toUpperCase(),
        style: BloomTextStyles.inter(
          size: 10,
          weight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}

class _BloomTextArea extends StatelessWidget {
  final TextEditingController controller;
  final int minLines;

  const _BloomTextArea({required this.controller, this.minLines = 2});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines + 2,
        style: BloomTextStyles.inter(
          size: 12,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}

class _MonoField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _MonoField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TextField(
        controller: controller,
        style: BloomTextStyles.mono(size: 11, color: AppColors.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: BloomTextStyles.mono(
            size: 11,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
