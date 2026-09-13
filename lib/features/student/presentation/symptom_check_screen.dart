import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'ai_result_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

// The API key is injected at build/run time instead of hardcoded in source.
// A key committed directly into Dart code ships inside the built app (APK/IPA)
// and can be extracted by anyone who inspects it — this is very likely why
// the previous hardcoded key started returning "Invalid API Key": exposed
// keys get caught by automated secret-scanning and revoked.
//
// Run with:  flutter run --dart-define=GROQ_API_KEY=your_new_key_here
// Build with: flutter build apk --dart-define=GROQ_API_KEY=your_new_key_here
//
// Get a key at https://console.groq.com/keys
const _groqApiKey = String.fromEnvironment('GROQ_API_KEY');
const _model = 'llama-3.3-70b-versatile';

const _systemPrompt = '''
You are a compassionate and professional medical assistant for university students.
Your job is to help students understand their symptoms and guide them on next steps.

Rules:
- Ask clarifying questions if needed
- Suggest possible causes clearly but never diagnose
- Always recommend one of these actions at the end:
  • "Book an appointment" for non-urgent issues
  • "Go to emergency" for urgent/severe symptoms
  • "Rest and monitor" for mild symptoms
- Keep responses concise, warm, and easy to understand
- Use simple language, avoid medical jargon
- Add a disclaimer that you are an AI and not a real doctor
''';

class SymptomCheckScreen extends StatefulWidget {
  const SymptomCheckScreen({super.key});

  @override
  State<SymptomCheckScreen> createState() => _SymptomCheckScreenState();
}

// Fixed symptom-tracker rows shown in the "noted symptoms" checklist card,
// matching the AI Symptom Checker design. Presence is inferred with a light
// keyword scan over everything the user has typed so far.
const List<_SymptomTracker> _kTrackedSymptoms = [
  _SymptomTracker(
    label: 'Headache',
    icon: Icons.psychology_alt_outlined,
    keywords: ['headache', 'head ache', 'migraine'],
  ),
  _SymptomTracker(
    label: 'Fever',
    icon: Icons.thermostat,
    keywords: ['fever'],
  ),
  _SymptomTracker(
    label: 'High Temperature',
    icon: Icons.device_thermostat,
    keywords: ['high temperature', 'temperature', 'hot to the touch'],
  ),
  _SymptomTracker(
    label: 'Nausea / Vomiting',
    icon: Icons.sick_outlined,
    keywords: ['nausea', 'nauseous', 'vomit', 'throwing up'],
  ),
  _SymptomTracker(
    label: 'Fatigue',
    icon: Icons.bedtime_outlined,
    keywords: ['fatigue', 'tired', 'exhausted', 'no energy'],
  ),
];

class _SymptomTracker {
  final String label;
  final IconData icon;
  final List<String> keywords;
  const _SymptomTracker({
    required this.label,
    required this.icon,
    required this.keywords,
  });
}

class _SymptomCheckScreenState extends State<SymptomCheckScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  bool _isTyping = false;
  bool _isAssessing = false;

  bool get _hasUserInput => _messages.any((m) => m.role == 'user');

  String get _combinedUserText => _messages
      .where((m) => m.role == 'user')
      .map((m) => m.text.toLowerCase())
      .join(' \n ');

  Set<String> get _presentSymptoms {
    final text = _combinedUserText;
    return {
      for (final s in _kTrackedSymptoms)
        if (s.keywords.any(text.contains)) s.label,
    };
  }

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _Msg(
        role: 'assistant',
        text:
            "Hi! I'm your AI health assistant 👋\n\nTell me what symptoms you're experiencing and I'll help you understand what might be going on and what to do next.",
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _isTyping = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    if (_groqApiKey.isEmpty) {
      setState(() {
        _isTyping = false;
        _messages.add(
          const _Msg(
            role: 'assistant',
            text:
                'The AI symptom checker isn\'t configured yet. It needs a '
                'Groq API key passed in at build time '
                '(--dart-define=GROQ_API_KEY=...). Get a free key at '
                'console.groq.com/keys.',
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    try {
      final history = _messages
          .where((m) => m.role != 'typing')
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                ...history,
              ],
              'temperature': 0.7,
              'max_tokens': 512,
            }),
          )
          .timeout(const Duration(seconds: 30)); // ✅ timeout added

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'] as String;
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(_Msg(role: 'assistant', text: reply.trim()));
          });
          _scrollToBottom();
        }
      } else {
        // ✅ show real HTTP error
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          // ✅ show real error in chat so we can debug
          _messages.add(
            _Msg(role: 'assistant', text: 'Error: ${e.toString()}'),
          );
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _getResult() async {
    if (!_hasUserInput || _isAssessing || _isTyping) return;
    setState(() => _isAssessing = true);

    const extractionPrompt = '''
Based on the conversation so far, respond with ONLY a JSON object (no markdown,
no commentary) in exactly this shape:
{"risk":"low|medium|high","headline":"short 4-8 word summary","description":"1-2 sentence plain-language explanation","notes":["short symptom note", "short symptom note"]}
''';

    try {
      final history = _messages
          .where((m) => m.role != 'typing')
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                ...history,
                {'role': 'user', 'content': extractionPrompt},
              ],
              'temperature': 0.2,
              'max_tokens': 300,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final raw = (data['choices'][0]['message']['content'] as String).trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (jsonMatch == null) throw Exception('No JSON in AI response');
      final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      final riskStr = (parsed['risk'] as String? ?? 'low').toLowerCase();
      final risk = switch (riskStr) {
        'high' => AiRiskLevel.high,
        'medium' || 'moderate' => AiRiskLevel.medium,
        _ => AiRiskLevel.low,
      };

      if (!mounted) return;
      context.push(
        '/ai-result',
        extra: {
          'risk': risk,
          'headline': parsed['headline'] as String? ?? 'Assessment complete',
          'description': parsed['description'] as String? ?? '',
          'notes': (parsed['notes'] as List?)?.cast<String>() ?? const [],
        },
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        userFriendlyErrorMessage(
          e,
          defaultMessage:
              'Could not generate symptom assessment right now. Please try again.',
        ),
        tone: AppStatusTone.danger,
      );
    } finally {
      if (mounted) setState(() => _isAssessing = false);
    }
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
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Symptom Checker',
                  style: TextStyle(
                    color: AppColors.surfaceInverse,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Powered by Llama 3',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_hasUserInput)
            IconButton(
              icon: _isAssessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: AppColors.accent,
                    ),
              tooltip: 'Get my result',
              onPressed: _getResult,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'New conversation',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  const _Msg(
                    role: 'assistant',
                    text:
                        "Hi! I'm your AI health assistant.\n\nTell me what symptoms you're experiencing and I'll help you understand what might be going on and what to do next.",
                  ),
                );
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.surfaceMuted),
        ),
      ),
      body: Column(
        children: [
          // ── Disclaimer banner ──────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.warningSurface,
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.warningDark),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI assistant only. Not a substitute for professional medical advice.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warningDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Messages ───────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              // +1 for the "noted symptoms" checklist card, once the user
              // has said something, and +1 for the typing indicator.
              itemCount:
                  _messages.length +
                  (_hasUserInput ? 1 : 0) +
                  (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_hasUserInput && i == _messages.length) {
                  return _SymptomChecklistBubble(present: _presentSymptoms);
                }
                final typingIndex = _messages.length + (_hasUserInput ? 1 : 0);
                if (_isTyping && i == typingIndex) {
                  return const _TypingBubble();
                }
                return _ChatBubble(msg: _messages[i]);
              },
            ),
          ),

          // ── Quick suggestions ──────────────────────────
          if (_messages.length == 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children:
                    [
                          'I have a headache',
                          'Fever and chills',
                          'Stomach pain',
                          'Sore throat',
                          'Feeling anxious',
                        ]
                        .map(
                          (s) => _SuggestionChip(
                            label: s,
                            onTap: () {
                              _ctrl.text = s;
                              _send();
                            },
                          ),
                        )
                        .toList(),
              ),
            )
          else if (_hasUserInput)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SuggestionChip(
                    label: 'Describe pain location',
                    icon: Icons.location_on_outlined,
                    onTap: () {
                      _ctrl.text = 'The pain is located in ';
                      _ctrl.selection = TextSelection.collapsed(
                        offset: _ctrl.text.length,
                      );
                    },
                  ),
                  _SuggestionChip(
                    label: 'How long has it lasted?',
                    icon: Icons.access_time,
                    onTap: () {
                      _ctrl.text = 'It has lasted for ';
                      _ctrl.selection = TextSelection.collapsed(
                        offset: _ctrl.text.length,
                      );
                    },
                  ),
                  _SuggestionChip(
                    label: 'Other symptoms?',
                    icon: Icons.add_circle_outline,
                    onTap: () {
                      _ctrl.text = 'I also have ';
                      _ctrl.selection = TextSelection.collapsed(
                        offset: _ctrl.text.length,
                      );
                    },
                  ),
                ],
              ),
            ),

          // ── Risk banner + actions ────────────────────────
          if (_hasUserInput)
            _RiskAssessmentPanel(
              isBusy: _isAssessing,
              onTap: _getResult,
              onBookAppointment: () => context.push('/book-appointment'),
              onEmergency: () => context.push('/emergency'),
              onSaveReport: _getResult,
            ),

          // ── Input bar ──────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.pageBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Describe your symptoms…',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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

// ── Chat Bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primaryLight : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
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
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.surfaceInverse,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primaryLight,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Typing Bubble ─────────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentDark],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Suggestion Chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primaryLight),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.surfaceInverse,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Symptom Checklist Bubble ────────────────────────────────────────────────
//
// Mirrors the "Thanks for sharing. I've noted the following symptoms:" card
// from the AI Symptom Checker design — a wide assistant bubble that lists a
// fixed set of tracked symptoms and whether the user has mentioned them yet.

class _SymptomChecklistBubble extends StatelessWidget {
  final Set<String> present;
  const _SymptomChecklistBubble({required this.present});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentDark],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Thanks for sharing. I've noted the following symptoms:",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surfaceInverse,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _kTrackedSymptoms.length; i++)
                          _SymptomRow(
                            tracker: _kTrackedSymptoms[i],
                            isPresent: present.contains(
                              _kTrackedSymptoms[i].label,
                            ),
                            showDivider: i != _kTrackedSymptoms.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "I'm gathering more information to better assess your condition.",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.textStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomRow extends StatelessWidget {
  final _SymptomTracker tracker;
  final bool isPresent;
  final bool showDivider;
  const _SymptomRow({
    required this.tracker,
    required this.isPresent,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: AppColors.surfaceMuted, width: 1),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPresent
                  ? AppColors.successSurface
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              tracker.icon,
              size: 16,
              color: isPresent
                  ? AppColors.success
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracker.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surfaceInverse,
                  ),
                ),
                Text(
                  isPresent ? 'Present' : 'Not specified',
                  style: TextStyle(
                    fontSize: 11,
                    color: isPresent
                        ? AppColors.success
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPresent ? AppColors.success : Colors.transparent,
              border: isPresent
                  ? null
                  : Border.all(color: AppColors.borderStrong, width: 1.5),
            ),
            child: isPresent
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Risk Assessment Panel ────────────────────────────────────────────────────
//
// The orange "Moderate Risk - Consultation Recommended" banner plus the
// Book Appointment / Emergency SOS / Save Report action row from the design.
// Tapping the banner (or Save Report) runs the real AI assessment.

class _RiskAssessmentPanel extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onBookAppointment;
  final VoidCallback onEmergency;
  final VoidCallback onSaveReport;

  const _RiskAssessmentPanel({
    required this.isBusy,
    required this.onTap,
    required this.onBookAppointment,
    required this.onEmergency,
    required this.onSaveReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isBusy ? null : onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(14),
                // A three-step orange ramp specific to the moderate-risk
                // callout; flattening it to one warning token would lose
                // the border/heading/body separation.
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warningDark,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moderate Risk - Consultation Recommended',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Based on the symptoms provided, we recommend consulting a healthcare professional.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isBusy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.warningDark,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.warningDark,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PanelButton(
                  label: 'Book Appointment',
                  icon: Icons.calendar_month,
                  background: AppColors.primaryLight,
                  foreground: Colors.white,
                  onTap: onBookAppointment,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PanelButton(
                  label: 'Emergency SOS',
                  icon: Icons.phone_in_talk,
                  background: AppColors.error,
                  foreground: Colors.white,
                  onTap: onEmergency,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PanelButton(
                  label: 'Save Report',
                  icon: Icons.description_outlined,
                  background: Colors.white,
                  foreground: AppColors.surfaceInverse,
                  border: AppColors.border,
                  onTap: isBusy ? null : onSaveReport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onTap;

  const _PanelButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Model ─────────────────────────────────────────────────────────────

class _Msg {
  final String role;
  final String text;
  const _Msg({required this.role, required this.text});
}
