import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';
import '../data/prescription_repository.dart';
import '../data/medication_models.dart';

/// Spec screen 13 - Post-Consultation Summary.
///
/// Expects a route `extra` map with:
/// - `doctorName` (String)
/// - `durationSeconds` (int)
class PostConsultationSummaryScreen extends StatefulWidget {
  final String doctorName;
  final int durationSeconds;

  const PostConsultationSummaryScreen({
    super.key,
    required this.doctorName,
    required this.durationSeconds,
  });

  @override
  State<PostConsultationSummaryScreen> createState() =>
      _PostConsultationSummaryScreenState();
}

class _PostConsultationSummaryScreenState
    extends State<PostConsultationSummaryScreen> {
  bool _loading = true;
  List<Prescription> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await PrescriptionRepository.instance.fetchPrescriptions();
      // Best-effort: prescriptions aren't linked to a specific appointment
      // in the current schema, so we surface the most recently issued ones.
      all.sort((a, b) => b.datePrescribed.compareTo(a.datePrescribed));
      if (mounted) {
        setState(() {
          _recent = all.take(3).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _durationLabel {
    final m = widget.durationSeconds ~/ 60;
    final s = widget.durationSeconds % 60;
    if (m <= 0) return '$s sec';
    return '$m min${s > 0 ? ' $s sec' : ''}';
  }

  Future<void> _downloadReport() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Visit Summary',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Doctor: ${widget.doctorName}'),
            pw.Text('Duration: $_durationLabel'),
            pw.Text('Date: ${DateTime.now().toIso8601String().split('T').first}'),
            pw.SizedBox(height: 16),
            pw.Text('Diagnosis',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              'Your doctor (${widget.doctorName}) will add diagnosis notes to '
              'your medical history shortly.',
            ),
            pw.SizedBox(height: 16),
            pw.Text('Recent prescriptions',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (_recent.isEmpty) pw.Text('No prescriptions issued yet for this visit.'),
            if (_recent.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['Medication', 'Dosage', 'Frequency'],
                data: _recent
                    .map((r) => [r.medicationName, r.dosage, r.frequency])
                    .toList(),
              ),
            pw.SizedBox(height: 16),
            pw.Text('Follow-up',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              'Return or book another visit if symptoms persist or worsen. '
              'Your full visit note will appear in Medical History once your '
              'doctor finalizes it.',
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const BloomScreenHeader(title: 'Visit summary', showBack: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Completed · $_durationLabel',
                        style: BloomTextStyles.inter(
                          size: 10,
                          weight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    BloomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DIAGNOSIS',
                            style: BloomTextStyles.inter(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.06,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your doctor (${widget.doctorName}) will add diagnosis '
                            'notes to your medical history shortly.',
                            style: BloomTextStyles.inter(
                              size: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const BloomSectionTitle('Recent prescriptions'),
                    BloomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          : _recent.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    'No prescriptions issued yet for this visit.',
                                    style: BloomTextStyles.inter(
                                      size: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (int i = 0; i < _recent.length; i++)
                                      BloomListItem(
                                        title: _recent[i].medicationName,
                                        subtitle:
                                            '${_recent[i].dosage} · ${_recent[i].frequency}',
                                        showBorder: i != _recent.length - 1,
                                      ),
                                  ],
                                ),
                    ),
                    const BloomSectionTitle('Follow-up'),
                    BloomCard(
                      child: Text(
                        'Return or book another visit if symptoms persist or '
                        'worsen. Your full visit note will appear in Medical '
                        'History once your doctor finalizes it.',
                        style: BloomTextStyles.inter(
                          size: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BloomButton(
                      label: 'Download report',
                      variant: BloomButtonVariant.ghost,
                      onPressed: _downloadReport,
                    ),
                    const SizedBox(height: 10),
                    BloomButton(
                      label: 'Done',
                      onPressed: () => context.go('/student-dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
