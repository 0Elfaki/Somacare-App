import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

const String _appId = String.fromEnvironment(
  'AGORA_APP_ID',
  defaultValue: '72656e25ae404defb07daea155e9806f',
);
const String _defaultChannel = 'consultation';

class ConsultScreen extends StatefulWidget {
  /// Optional channel override - pass via GoRouter extra:
  /// `context.push('/consult', extra: {'channelId': 'appointment_xyz'})`
  final String? channelId;
  final String? doctorName;

  const ConsultScreen({super.key, this.channelId, this.doctorName});

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localJoined = false;
  bool _micMuted = false;
  bool _camOff = false;
  bool _isLoading = true;
  bool _isEndingCall = false;
  String? _initError;
  final Stopwatch _callTimer = Stopwatch();
  Timer? _uiTicker;

  String get _channelId => widget.channelId ?? _defaultChannel;

  String get _elapsedLabel {
    final s = _callTimer.elapsed.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  void initState() {
    super.initState();
    _callTimer.start();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _initAgora();
  }

  /// Fetches a short-lived Agora RTC token from the `agora-token` Supabase
  /// Edge Function, which holds the App Certificate server-side. Returns an
  /// empty string (join without a token) if the function isn't deployed yet
  /// or the call fails - that only works on Agora projects without App
  /// Certificate security enabled.
  Future<String> _fetchAgoraToken(String channelName) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'agora-token',
        body: {'channelName': channelName, 'uid': 0},
      );
      final token = (res.data as Map?)?['token'] as String?;
      return token ?? '';
    } catch (e) {
      debugPrint('[ConsultScreen] Could not fetch Agora token: $e');
      return '';
    }
  }

  Future<void> _initAgora() async {
    if (_appId.isEmpty) {
      // No Agora App ID configured (run with
      // --dart-define=AGORA_APP_ID=<your id>). Fail gracefully instead of
      // letting the SDK throw on an empty app ID.
      if (mounted) {
        setState(() {
          _initError = 'Video calling isn\'t configured yet.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      await [Permission.microphone, Permission.camera].request();

      final token = await _fetchAgoraToken(_channelId);

      final engine = createAgoraRtcEngine();
      await engine.initialize(const RtcEngineContext(appId: _appId));

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (mounted) {
              setState(() {
                _localJoined = true;
                _isLoading = false;
              });
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (mounted) setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (mounted) setState(() => _remoteUid = null);
          },
          onError: (err, msg) {
            if (mounted) {
              setState(() {
                _initError = 'Video call error: $msg';
                _isLoading = false;
              });
            }
          },
        ),
      );

      await engine.enableVideo();
      await engine.startPreview();
      await engine.joinChannel(
        token: token,
        channelId: _channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (mounted) setState(() => _engine = engine);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Could not start the video call: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _endCall() async {
    if (_isEndingCall) return;
    setState(() => _isEndingCall = true);
    _callTimer.stop();

    try {
      await _engine?.leaveChannel().timeout(const Duration(milliseconds: 500), onTimeout: () {});
    } catch (_) {}
    try {
      await _engine?.release().timeout(const Duration(milliseconds: 500), onTimeout: () {});
    } catch (_) {}

    if (!mounted) return;
    context.pushReplacement(
      '/post-consultation-summary',
      extra: {
        'doctorName': widget.doctorName ?? 'your doctor',
        'durationSeconds': _callTimer.elapsed.inSeconds,
      },
    );
  }

  void _toggleMic() {
    setState(() => _micMuted = !_micMuted);
    _engine?.muteLocalAudioStream(_micMuted);
  }

  void _toggleCam() {
    setState(() => _camOff = !_camOff);
    _engine?.muteLocalVideoStream(_camOff);
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _engine?.leaveChannel().catchError((_) {});
    _engine?.release().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _endCall();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _initError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _endCall,
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final engine = _engine;

    // ✅ PopScope intercepts Android hardware back button
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Remote video ──────────────────────────────
            (_remoteUid != null && engine != null)
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: engine,
                      canvas: VideoCanvas(uid: _remoteUid),
                      connection: RtcConnection(channelId: _channelId),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Waiting for doctor to join…',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(height: 20),
                          const CircularProgressIndicator(
                            color: Colors.white38,
                          ),
                        ],
                      ],
                    ),
                  ),

            // ── Call timer badge ───────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        // The in-call surface is black, so it keeps the legacy lime
                        // accent rather than the light-theme tokens.
                        color: LegacyDarkColors.lime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _elapsedLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Local video PiP ───────────────────────────
            if (_localJoined && !_camOff && engine != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),

            // ── Top bar ───────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 12,
                  16,
                  12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _endCall, // ✅ always cleans up Agora
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Video Consultation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Secure medical call',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
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
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Live',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom controls ───────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlBtn(
                      icon: _micMuted ? Icons.mic_off : Icons.mic,
                      label: _micMuted ? 'Unmute' : 'Mute',
                      onTap: _toggleMic,
                      active: !_micMuted,
                    ),
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    _ControlBtn(
                      icon: _camOff ? Icons.videocam_off : Icons.videocam,
                      label: _camOff ? 'Show Cam' : 'Hide Cam',
                      onTap: _toggleCam,
                      active: !_camOff,
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

// ── Control Button ────────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.textStrong,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
