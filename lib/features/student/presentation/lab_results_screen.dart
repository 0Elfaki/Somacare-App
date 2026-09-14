import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';
import '../data/lab_result_model.dart';
import '../data/lab_result_repository.dart';

/// Spec screen 16 - Lab Results Trend.
class LabResultsScreen extends StatefulWidget {
  const LabResultsScreen({super.key});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  bool _isLoading = true;
  List<LabResult> _results = [];
  String? _selectedTest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await LabResultRepository.instance.fetchMine();
    if (!mounted) return;
    setState(() {
      _results = results;
      _selectedTest = results.isNotEmpty ? results.first.testName : null;
      _isLoading = false;
    });
  }

  List<LabResult> get _trend {
    if (_selectedTest == null) return [];
    final list =
        _results.where((r) => r.testName == _selectedTest).toList();
    list.sort((a, b) => a.testDate.compareTo(b.testDate));
    return list;
  }

  Color _statusColor(LabResultStatus s) => switch (s) {
        LabResultStatus.normal => AppColors.success,
        LabResultStatus.abnormal => AppColors.warning,
        LabResultStatus.critical => AppColors.error,
      };

  Future<void> _downloadReport() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Lab Results Report',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Generated ${DateTime.now().toIso8601String().split('T').first}'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Test', 'Date', 'Value', 'Range', 'Status'],
              data: _results
                  .map((r) => [
                        r.testName,
                        r.testDate.toIso8601String().split('T').first,
                        '${r.value}${r.unit != null ? ' ${r.unit}' : ''}',
                        r.rangeLabel,
                        r.status.name,
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final testNames = _results.map((r) => r.testName).toSet().toList();

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            BloomScreenHeader(
              title: _selectedTest == null
                  ? 'Lab results'
                  : '$_selectedTest trend',
              trailing: [
                if (_results.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        color: AppColors.success, size: 20),
                    onPressed: _downloadReport,
                    tooltip: 'Download report',
                  ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No lab results on file yet. Your doctor will '
                              'add results here after tests are processed.',
                              textAlign: TextAlign.center,
                              style: BloomTextStyles.inter(
                                size: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (testNames.length > 1)
                                BloomFilterChips(
                                  options: testNames,
                                  selected: _selectedTest ?? testNames.first,
                                  onSelect: (v) =>
                                      setState(() => _selectedTest = v),
                                ),
                              const SizedBox(height: 14),
                              BloomCard(
                                child: SizedBox(
                                  height: 130,
                                  child: CustomPaint(
                                    painter: _TrendPainter(
                                      results: _trend,
                                      statusColor: _statusColor,
                                    ),
                                    child: Container(),
                                  ),
                                ),
                              ),
                              const BloomSectionTitle('Results'),
                              BloomCard(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 15),
                                child: Column(
                                  children: [
                                    for (int i = 0; i < _trend.length; i++)
                                      BloomListItem(
                                        title: _trend[_trend.length - 1 - i]
                                            .testDate
                                            .toIso8601String()
                                            .split('T')
                                            .first,
                                        subtitle: _trend[_trend.length - 1 - i]
                                            .rangeLabel,
                                        showBorder: i != _trend.length - 1,
                                        trailing: BloomTextBadge(
                                          label:
                                              '${_trend[_trend.length - 1 - i].value}'
                                              '${_trend[_trend.length - 1 - i].unit ?? ''}',
                                          status: _trend[_trend.length - 1 - i]
                                                      .status ==
                                                  LabResultStatus.normal
                                              ? BloomBadgeStatus.active
                                              : _trend[_trend.length - 1 - i]
                                                          .status ==
                                                      LabResultStatus.abnormal
                                                  ? BloomBadgeStatus.pending
                                                  : BloomBadgeStatus.danger,
                                        ),
                                      ),
                                  ],
                                ),
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

class _TrendPainter extends CustomPainter {
  final List<LabResult> results;
  final Color Function(LabResultStatus) statusColor;

  _TrendPainter({required this.results, required this.statusColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    final values = results.map((r) => r.value).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1 : (maxV - minV);

    final dx = results.length > 1 ? size.width / (results.length - 1) : 0.0;
    final points = <Offset>[];
    for (int i = 0; i < results.length; i++) {
      final x = results.length == 1 ? size.width / 2 : dx * i;
      final normalized = (results[i].value - minV) / range;
      final y = size.height - (normalized * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    if (points.length > 1) canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        3.5,
        Paint()..color = statusColor(results[i].status),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.results != results;
}
