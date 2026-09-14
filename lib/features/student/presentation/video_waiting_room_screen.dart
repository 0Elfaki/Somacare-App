import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';

/// Spec screen 11 - Video Waiting Room.
///
/// A short connecting screen shown before the student is dropped into
/// [ConsultScreen]. Expects a route `extra` map with:
/// - `doctorName` (String)
/// - `channelId` (String?) - forwarded to `/consult`
class VideoWaitingRoomScreen extends StatefulWidget {
  final String doctorName;
  final String? channelId;

  const VideoWaitingRoomScreen({
    super.key,
    required this.doctorName,
    this.channelId,
  });

  @override
  State<VideoWaitingRoomScreen> createState() =>
      _VideoWaitingRoomScreenState();
}

class _VideoWaitingRoomScreenState extends State<VideoWaitingRoomScreen> {
  late final Timer _ticker;
  late final Timer _autoJoin;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    // Brief connecting delay before dropping into the real call screen - // ConsultScreen itself shows a "waiting for doctor" state if the
    // remote party hasn't joined yet.
    _autoJoin = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        context.pushReplacement(
          '/consult',
          extra: {'channelId': widget.channelId},
        );
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _autoJoin.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Waiting for ${widget.doctorName}',
                  style: BloomTextStyles.fraunces(
                    size: 17,
                    weight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "They'll join shortly, hang tight",
                  style: BloomTextStyles.inter(
                    size: 11.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _mmss,
                  style: BloomTextStyles.mono(
                    size: 26,
                    weight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Cancel',
                      style: BloomTextStyles.inter(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
