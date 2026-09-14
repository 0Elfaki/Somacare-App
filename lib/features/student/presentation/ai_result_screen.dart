import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

enum AiRiskLevel { low, medium, high }

/// Spec screen 7 - AI Result Screen.
///
/// Expects a route `extra` map with:
/// - `risk` (String: 'low' | 'medium' | 'high')
/// - `headline` (String)
/// - `description` (String)
/// - `notes` (`List<String>`)
class AiResultScreen extends StatelessWidget {
  final AiRiskLevel risk;
  final String headline;
  final String description;
  final List<String> notes;

  const AiResultScreen({
    super.key,
    required this.risk,
    required this.headline,
    required this.description,
    this.notes = const [],
  });

  Color get _riskColor => switch (risk) {
        AiRiskLevel.low => AppColors.success,
        AiRiskLevel.medium => AppColors.warning,
        AiRiskLevel.high => AppColors.error,
      };

  String get _riskLabel => switch (risk) {
        AiRiskLevel.low => 'LOW RISK',
        AiRiskLevel.medium => 'MEDIUM RISK',
        AiRiskLevel.high => 'HIGH RISK',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const BloomScreenHeader(title: 'Your result'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.cardAll,
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.cardAll,
                          border: Border(
                            left: BorderSide(color: _riskColor, width: 4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _riskColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: _riskColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _riskLabel,
                                    style: BloomTextStyles.inter(
                                      size: 10,
                                      weight: FontWeight.w600,
                                      color: _riskColor,
                                      letterSpacing: 0.04,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              headline,
                              style: BloomTextStyles.fraunces(
                                size: 17,
                                weight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              description,
                              style: BloomTextStyles.inter(
                                size: 12,
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const BloomSectionTitle('What we noted'),
                      BloomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: notes
                              .map(
                                (n) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $n',
                                    style: BloomTextStyles.inter(
                                      size: 12,
                                      color: AppColors.textPrimary,
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: BloomButton(
                            label: 'Self-care tips',
                            variant: BloomButtonVariant.ghost,
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: Text(
                                  'Self-care tips',
                                  style: BloomTextStyles.inter(
                                    weight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                content: Text(
                                  'Rest, stay hydrated, and monitor your '
                                  'symptoms. Book an appointment if things '
                                  "don't improve or get worse.",
                                  style: BloomTextStyles.inter(
                                    size: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Got it'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BloomButton(
                            label: 'Book anyway',
                            onPressed: () => context.push('/book-appointment'),
                          ),
                        ),
                      ],
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
