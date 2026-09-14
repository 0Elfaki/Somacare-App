import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

/// Spec screen 25 - Ambulance Live Tracking.
///
/// There is no live ambulance-dispatch backend yet, so ETA/driver/stepper
/// state is simulated locally (mirrors the demo-data fallback pattern
/// already used by [MedicalHistoryRepository]) - this screen still performs
/// a real Supabase write via the emergency request that pushed it, it just
/// doesn't yet have a live GPS feed to render.
class AmbulanceTrackingScreen extends StatefulWidget {
  final String? note;

  const AmbulanceTrackingScreen({super.key, this.note});

  @override
  State<AmbulanceTrackingScreen> createState() =>
      _AmbulanceTrackingScreenState();
}

class _AmbulanceTrackingScreenState extends State<AmbulanceTrackingScreen> {
  static const _totalEtaSeconds = 7 * 60;
  late int _remainingSeconds = _totalEtaSeconds;
  late final Timer _ticker;
  int _stage = 0; // 0=dispatched, 1=on the way, 2=arrived

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          final elapsedFrac =
              1 - (_remainingSeconds / _totalEtaSeconds);
          _stage = elapsedFrac >= 0.95 ? 2 : (elapsedFrac >= 0.1 ? 1 : 0);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String get _etaLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    if (m <= 0) return '$s sec';
    return s == 0 ? '$m min' : '$m min $s sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const BloomScreenHeader(title: 'Ambulance en route', showBack: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BloomMapPlaceholder(height: 190, showAmbulance: _stage < 2),
                    const SizedBox(height: 12),
                    BloomCard(
                      child: Column(
                        children: [
                          Text(
                            'ESTIMATED ARRIVAL',
                            style: BloomTextStyles.inter(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.06,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _stage == 2 ? 'Arrived' : _etaLabel,
                            style: BloomTextStyles.mono(
                              size: 24,
                              weight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BloomCard(
                      child: Row(
                        children: [
                          const BloomAvatar(size: 36),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver: Kato M.',
                                style: BloomTextStyles.inter(
                                  size: 12.5,
                                  weight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Mulago Ambulance Unit 03',
                                style: BloomTextStyles.inter(
                                  size: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if ((widget.note ?? '').isNotEmpty) ...[
                      const BloomSectionTitle('Reported'),
                      BloomCard(
                        child: Text(
                          widget.note!,
                          style: BloomTextStyles.inter(
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _StepDot(label: 'Dispatched', active: _stage >= 0),
                        _StepDot(label: 'On the way', active: _stage >= 1),
                        _StepDot(label: 'Arrived', active: _stage >= 2, isLast: true),
                      ],
                    ),
                    if (_stage == 2) ...[
                      const SizedBox(height: 20),
                      BloomButton(
                        label: 'Done',
                        onPressed: () => context.go('/student-dashboard'),
                      ),
                    ],
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

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool isLast;

  const _StepDot({required this.label, required this.active, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (!isLast)
                Positioned(
                  left: 10,
                  right: -10,
                  child: Container(
                    height: 2,
                    color: active
                        ? AppColors.primary
                        : AppColors.surfaceMuted,
                  ),
                ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: active
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: BloomTextStyles.inter(
              size: 9,
              weight: FontWeight.w600,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
