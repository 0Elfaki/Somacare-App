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

class DoctorConsultScreen extends StatefulWidget {
  final Map<String, dynamic> extra;

  const DoctorConsultScreen({super.key, required this.extra});

  @override
  State<DoctorConsultScreen> createState() => _DoctorConsultScreenState();
}

class _DoctorConsultScreenState extends State<DoctorConsultScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localJoined = false;
  bool _micMuted = false;
  bool _camOff = false;
  bool _isLoading = true;
  bool _isEndingCall = false;
  String? _initError;

  String get _channelId {
    final appointmentId = widget.extra['appointmentId'] as String?;
    if (appointmentId != null && appointmentId.isNotEmpty) {
      return 'appointment_$appointmentId';
    }
    return 'consultation';
  }

  String get _studentName =>
      (widget.extra['studentName'] as String?) ?? 'Patient';

  @override
  void initState() {
    super.initState();
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
      debugPrint('[DoctorConsultScreen] Could not fetch Agora token: $e');
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

    // Quick cleanup - don't block navigation
    try {
      await _engine?.leaveChannel().timeout(const Duration(milliseconds: 500), onTimeout: () {});
    } catch (_) {}
    try {
      await _engine?.release().timeout(const Duration(milliseconds: 500), onTimeout: () {});
    } catch (_) {}

    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/doctor-dashboard');
    }
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

    // PopScope intercepts Android hardware back button
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Remote video (full screen) ────────────────
            if (_remoteUid != null && engine != null)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: RtcConnection(channelId: _channelId),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLoading
                          ? 'Connecting...'
                          : 'Waiting for $_studentName...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(color: Colors.white54),
                    ],
                  ],
                ),
              ),

            // ── Local video (picture-in-picture) ──────────
            if (_localJoined && !_camOff && engine != null)
              Positioned(
                top: 60,
                right: 16,
                width: 100,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              color: AppColors.success,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Consulting: $_studentName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Controls ──────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 32,
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
                      // Mute mic
                      _ControlButton(
                        icon: _micMuted ? Icons.mic_off : Icons.mic,
                        label: _micMuted ? 'Unmute' : 'Mute',
                        onTap: _toggleMic,
                        isActive: !_micMuted,
                      ),

                      // End call
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

                      // Toggle camera
                      _ControlButton(
                        icon: _camOff ? Icons.videocam_off : Icons.videocam,
                        label: _camOff ? 'Cam On' : 'Cam Off',
                        onTap: _toggleCam,
                        isActive: !_camOff,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ), // closes Scaffold
    ); // closes PopScope
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
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
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white70 : Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
