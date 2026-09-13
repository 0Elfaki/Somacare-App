import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/message_model.dart';
import '../data/message_repository.dart';
import '../../../theme/app_theme.dart';

/// Text-messaging screen between a student and their doctor — bubbles, an
/// attached image, a voice note, and a live typing indicator.
///
/// Requires [doctorId]: with a signed-in student and a known doctor, the
/// thread is loaded from and persisted to the `messages` Supabase table in
/// realtime (see `lib/features/student/data/create_messages.sql`). If
/// [doctorId] is missing — this screen was reached without a specific
/// doctor to message — it shows a prompt to pick one from a confirmed
/// appointment rather than fabricating a conversation.
class MessagingChatScreen extends StatefulWidget {
  final String doctorName;
  final String doctorSpecialty;
  final String? doctorId;
  final String? appointmentId;

  const MessagingChatScreen({
    super.key,
    this.doctorName = 'Your doctor',
    this.doctorSpecialty = 'General Physician',
    this.doctorId,
    this.appointmentId,
  });

  @override
  State<MessagingChatScreen> createState() => _MessagingChatScreenState();
}

class _MessagingChatScreenState extends State<MessagingChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  final Set<String> _seenIds = {};
  bool _isTyping = false;
  bool _isLoading = false;
  RealtimeChannel? _channel;

  String? get _studentId => Supabase.instance.client.auth.currentUser?.id;

  /// True once we have both a signed-in student and a known doctor, so we
  /// can talk to the real `messages` table instead of showing demo data.
  bool get _isLive => _studentId != null && widget.doctorId != null;

  @override
  void initState() {
    super.initState();
    if (_isLive) {
      _loadLiveThread();
    }
  }

  Future<void> _loadLiveThread() async {
    final studentId = _studentId;
    final doctorId = widget.doctorId;
    if (studentId == null || doctorId == null) return;

    setState(() => _isLoading = true);
    final history = await MessageRepository.instance.fetchThread(
      studentId: studentId,
      doctorId: doctorId,
    );
    if (!mounted) return;
    setState(() {
      for (final m in history) {
        _seenIds.add(m.id);
        _messages.add(_ChatMessage.fromModel(m, meId: studentId));
      }
      _isLoading = false;
    });
    _scrollToBottom();
    unawaited(
      MessageRepository.instance.markThreadRead(
        studentId: studentId,
        doctorId: doctorId,
        readerId: studentId,
      ),
    );

    _channel = MessageRepository.instance.subscribe(
      studentId: studentId,
      doctorId: doctorId,
      onInsert: (message) {
        if (!mounted || _seenIds.contains(message.id)) return;
        _seenIds.add(message.id);
        setState(() {
          _messages.add(_ChatMessage.fromModel(message, meId: studentId));
          if (!message.isFromMe(studentId)) _isTyping = false;
        });
        _scrollToBottom();
      },
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    if (!_isLive) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _sendLive(text);
  }

  Future<void> _sendLive(String text) async {
    final studentId = _studentId;
    final doctorId = widget.doctorId;
    if (studentId == null || doctorId == null) return;

    setState(() => _isTyping = true);
    final sent = await MessageRepository.instance.sendMessage(
      studentId: studentId,
      doctorId: doctorId,
      senderId: studentId,
      body: text,
      appointmentId: widget.appointmentId,
    );
    if (!mounted) return;
    setState(() => _isTyping = false);

    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message. Try again.')),
      );
      return;
    }
    if (!_seenIds.contains(sent.id)) {
      _seenIds.add(sent.id);
      setState(() {
        _messages.add(_ChatMessage.fromModel(sent, meId: studentId));
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: AppColors.surfaceInverse),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/student-dashboard'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.accent],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 22),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctorName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.surfaceInverse,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_isLive)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppColors.textSecondary),
            tooltip: 'Start video call',
            onPressed: _isLive
                ? () => context.push(
                      '/consult',
                      extra: {'doctorName': widget.doctorName},
                    )
                : null,
          ),
          IconButton(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.surfaceMuted),
        ),
      ),
      body: !_isLive
          ? _NoDoctorSelected(
              onPickDoctor: () => context.canPop()
                  ? context.pop()
                  : context.go('/my-appointments'),
            )
          : Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryLight,
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (_isTyping && i == _messages.length) {
                              return _DoctorTypingRow(
                                doctorName: widget.doctorName,
                              );
                            }
                            return _MessageBubble(msg: _messages[i]);
                          },
                        ),
                ),

                // ── Input bar ──────────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    MediaQuery.of(context).padding.bottom + 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceMuted),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppColors.pageBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  maxLines: 4,
                                  minLines: 1,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Attach a file',
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                tooltip: 'Take a photo',
                                icon: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
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

// ── No doctor selected ───────────────────────────────────────────────────────

class _NoDoctorSelected extends StatelessWidget {
  final VoidCallback onPickDoctor;
  const _NoDoctorSelected({required this.onPickDoctor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No conversation yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Messaging opens from a confirmed appointment. Pick a doctor from your appointments to start a conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onPickDoctor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Go to my appointments',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message model ────────────────────────────────────────────────────────────

enum _MessageType { text, image, voice }

class _ChatMessage {
  final bool isMe;
  final _MessageType type;
  final String? text;
  final String time;
  final String? durationLabel;
  final String? attachmentUrl;

  const _ChatMessage({
    required this.isMe,
    required this.type,
    required this.time,
    this.text,
    this.durationLabel,
    this.attachmentUrl,
  });

  /// Converts a persisted [ChatMessageModel] (from Supabase) into the
  /// widget-local display model, formatting its timestamp and figuring out
  /// which side of the thread it belongs on relative to [meId].
  factory _ChatMessage.fromModel(ChatMessageModel m, {required String meId}) {
    final type = switch (m.type) {
      MessageType.image => _MessageType.image,
      MessageType.voice => _MessageType.voice,
      MessageType.text => _MessageType.text,
    };
    final local = m.createdAt.toLocal();
    final hour = local.hourOfPeriod12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return _ChatMessage(
      isMe: m.isFromMe(meId),
      type: type,
      text: m.body,
      time: '$hour:$minute $period',
      durationLabel: m.voiceDurationSeconds != null
          ? _formatDuration(m.voiceDurationSeconds!)
          : null,
      attachmentUrl: m.attachmentUrl,
    );
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

extension _HourOfPeriod on DateTime {
  int get hourOfPeriod12 {
    final h = hour % 12;
    return h == 0 ? 12 : h;
  }
}

// ── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    Widget content;
    switch (msg.type) {
      case _MessageType.text:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text ?? '',
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.surfaceInverse,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        );
        break;
      case _MessageType.image:
        content = ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          child: SizedBox(
            width: 200,
            height: 150,
            child: msg.attachmentUrl != null
                ? Image.network(
                    msg.attachmentUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.textPrimary,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 36,
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.textPrimary,
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white54,
                        size: 36,
                      ),
                    ),
                  ),
          ),
        );
        break;
      case _MessageType.voice:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white : AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: isMe ? AppColors.primaryLight : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              _Waveform(color: isMe ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 10),
              Text(
                msg.durationLabel ?? '0:00',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [Flexible(child: content)],
          ),
          if (msg.time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                msg.time,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  final Color color;
  const _Waveform({required this.color});

  static const _heights = [
    6.0, 12.0, 8.0, 16.0, 10.0, 18.0, 9.0, 14.0, 7.0, 16.0, 11.0, 8.0,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final h in _heights)
            Container(
              width: 2.5,
              height: h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Typing indicator row ─────────────────────────────────────────────────────

class _DoctorTypingRow extends StatelessWidget {
  final String doctorName;
  const _DoctorTypingRow({required this.doctorName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDots(),
                const SizedBox(width: 8),
                Text(
                  '$doctorName is typing…',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 8,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final t = ((_ctrl.value + i * 0.2) % 1.0);
              final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Opacity(
                opacity: 0.4 + 0.6 * scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
