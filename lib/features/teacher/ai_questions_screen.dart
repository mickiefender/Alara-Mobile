import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alara/theme.dart';
import 'package:alara/services/ai_questions_service.dart';
import 'package:alara/services/chat_history_service.dart';

class AiQuestionsScreen extends StatefulWidget {
  const AiQuestionsScreen({super.key});

  @override
  State<AiQuestionsScreen> createState() => _AiQuestionsScreenState();
}

class _AiQuestionsScreenState extends State<AiQuestionsScreen>
    with TickerProviderStateMixin {
  final _service = AiQuestionsService();
  final _historyService = ChatHistoryService();
  final _topicController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];

  // Current session tracking
  String? _currentSessionId;
  bool _isNewSession = true;

  bool _isGenerating = false;
  String _subject = '';
  String _difficulty = 'medium';
  String _questionType = 'multiple_choice';
  int _numQuestions = 5;
  DocumentInfo? _selectedDocument;
  List<DocumentInfo> _documents = [];
  bool _isLoadingDocs = false;
  bool _showInput = true;
  GenerationSource _source = GenerationSource.topic;

  // History
  List<ChatSession> _sessions = [];
  bool _isLoadingHistory = false;

  // Animations
  late AnimationController _robotPulseController;
  late AnimationController _robotRotateController;
  late AnimationController _generatingPulseController;
  late Animation<double> _robotPulse;
  late Animation<double> _robotRotate;

  @override
  void initState() {
    super.initState();

    // Robot floating pulse animation
    _robotPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _robotPulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _robotPulseController, curve: Curves.easeInOut),
    );

    // Robot slow rotation animation
    _robotRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _robotRotate = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _robotRotateController, curve: Curves.linear),
    );

    // Generating pulse effect
    _generatingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadDocuments();
    _loadHistoryList();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _robotPulseController.dispose();
    _robotRotateController.dispose();
    _generatingPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments({bool forceRefresh = false}) async {
    if (_isLoadingDocs && !forceRefresh) return;
    setState(() => _isLoadingDocs = true);
    final docs = await _service.fetchDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        if (_selectedDocument != null &&
            !_documents.any((d) => d.id == _selectedDocument!.id)) {
          _selectedDocument = null;
        }
        _isLoadingDocs = false;
      });
    }
  }

  Future<void> _loadHistoryList() async {
    setState(() => _isLoadingHistory = true);
    final sessions = await _historyService.loadSessionList();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoadingHistory = false;
      });
    }
  }

  void _addMessage(String text,
      {required bool isUser,
      bool isWelcome = false,
      List<GeneratedQuestion>? questions}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        isWelcome: isWelcome,
        questions: questions,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateQuestions() async {
    final topic = _topicController.text.trim();

    if (_source == GenerationSource.topic && topic.isEmpty) return;
    if (_source == GenerationSource.document && _selectedDocument == null) {
      _showSnackBar('Please select a learning material first');
      return;
    }

    setState(() => _isGenerating = true);

    final userMsg = StringBuffer();
    userMsg.writeln('**Generate Questions**');
    userMsg.writeln('');
    userMsg
        .writeln('• **Topic:** ${topic.isNotEmpty ? topic : (_selectedDocument?.title ?? "From document")}');
    if (_subject.isNotEmpty) userMsg.writeln('• **Subject:** $_subject');
    userMsg.writeln(
        '• **Difficulty:** ${_difficulty[0].toUpperCase()}${_difficulty.substring(1)}');
    userMsg.writeln(
        '• **Type:** ${_questionType.replaceAll("_", " ").split(" ").map((w) => w[0].toUpperCase() + w.substring(1)).join(" ")}');
    userMsg.writeln('• **Count:** $_numQuestions questions');
    _addMessage(userMsg.toString(), isUser: true);

    // Add generating animation message
    _addGeneratingMessage();
    setState(() => _showInput = false);

    final result = await _service.generateQuestions(
      topic: topic,
      subject: _subject,
      numQuestions: _numQuestions,
      questionType: _questionType,
      difficulty: _difficulty,
      documentId:
          _source == GenerationSource.document ? _selectedDocument?.id : null,
    );

    if (!mounted) return;
    _generatingPulseController.stop();
    setState(() => _isGenerating = false);

    if (result.error != null) {
      _replaceLastMessage(
          '❌ **Sorry, something went wrong**\n\n${result.error}\n\nPlease try again with a different topic or check your connection.');
    } else if (result.questions.isEmpty && result.rawResponse != null) {
      _replaceLastMessage('📝 **Raw Response Received**\n\n${result.rawResponse}');
    } else if (result.questions.isNotEmpty) {
      _replaceLastQuestionResults(result);
    } else {
      _replaceLastMessage(
          '⚠️ No questions were generated. Please try being more specific about your topic.');
    }

    setState(() => _showInput = true);
    _topicController.clear();
  }

  void _addGeneratingMessage() {
    _generatingPulseController.repeat(reverse: true);
    setState(() {
      _messages.add(ChatMessage(
        text: '',
        isUser: false,
        isGenerating: true,
      ));
    });
    _scrollToBottom();
  }

  void _replaceLastMessage(String text) {
    setState(() {
      if (_messages.isNotEmpty) _messages.removeLast();
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _replaceLastQuestionResults(AiGenerationResult result) {
    final buf = StringBuffer();
    buf.writeln('✅ **Questions Generated Successfully!**');
    if (result.aiName != null) buf.writeln('🤖 *Powered by ${result.aiName}*');
    buf.writeln('');

    for (int i = 0; i < result.questions.length; i++) {
      final q = result.questions[i];
      final qNum = i + 1;

      buf.writeln('**Q$qNum:** ${q.question}');
      buf.writeln('');

      if (q.options != null && q.options!.isNotEmpty) {
        for (int j = 0; j < q.options!.length; j++) {
          final label = String.fromCharCode(65 + j);
          final optionText = q.options![j];
          final cleanOption =
              optionText.replaceAll(RegExp(r'^[A-D][).]\s*'), '');
          buf.writeln(
              '${_isCorrect(q, label) ? "✅" : "  "} **$label.** $cleanOption');
        }
        buf.writeln('');
        buf.writeln('> **Answer:** ${q.correctAnswer ?? ""}');
      }

      if (q.explanation != null && q.explanation!.isNotEmpty) {
        buf.writeln('> 💡 *${q.explanation}*');
      }

      if (q.modelAnswer != null && q.modelAnswer!.isNotEmpty) {
        buf.writeln('> **Model Answer:** ${q.modelAnswer}');
      }

      if (q.markingPoints != null && q.markingPoints!.isNotEmpty) {
        buf.writeln('> **Key Points:**');
        for (final point in q.markingPoints!) {
          buf.writeln('> • $point');
        }
      }

      buf.writeln('');
      buf.writeln('---');
      buf.writeln('');
    }

    buf.writeln('📋 **Total:** ${result.questions.length} questions generated');

    setState(() {
      if (_messages.isNotEmpty) _messages.removeLast();
      _messages.add(ChatMessage(
        text: buf.toString(),
        isUser: false,
        questions: result.questions,
      ));
    });
    _scrollToBottom();

    // Save session to history after successful generation
    _saveCurrentSession();
  }

  bool _isCorrect(GeneratedQuestion q, String label) {
    if (q.correctAnswer == null) return false;
    final answer = q.correctAnswer!.trim().toUpperCase();
    return answer == label ||
        answer ==
            q.options
                ?.indexWhere((opt) => opt.startsWith(label))
                .toString();
  }

  void _clearChat() {
    if (_currentSessionId != null && _messages.length > 1) {
      _saveCurrentSession();
    }
    setState(() {
      _messages.clear();
      _topicController.clear();
      _selectedDocument = null;
      _showInput = true;
      _isNewSession = true;
      _currentSessionId = null;
    });
    _loadHistoryList();
  }

  void _openSession(ChatSession session) {
    if (_messages.length > 1) {
      _saveCurrentSession();
    }

    if (session.messages.isEmpty) {
      _loadFullSession(session.id);
      return;
    }

    _applySession(session);
  }

  Future<void> _loadFullSession(String sessionId) async {
    final allSessions = await _historyService.loadSessions();
    final session = allSessions.where((s) => s.id == sessionId).firstOrNull;
    if (session != null && mounted) {
      _applySession(session);
    }
  }

  void _applySession(ChatSession session) {
    setState(() {
      _messages.clear();
      _currentSessionId = session.id;
      _isNewSession = false;

      _source = session.source;
      _subject = session.subject ?? '';
      _difficulty = session.difficulty ?? 'medium';
      _questionType = session.questionType ?? 'multiple_choice';
      _showInput = true;

      for (final persistedMsg in session.messages) {
        _messages.add(ChatMessage(
          text: persistedMsg.text,
          isUser: persistedMsg.isUser,
          isWelcome: persistedMsg.isWelcome,
          questions: persistedMsg.questions
              ?.map((q) => q.toGeneratedQuestion())
              .toList(),
        ));
      }
    });
    _scrollToBottom();
  }

  Future<void> _saveCurrentSession() async {
    if (_messages.length <= 1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = _currentSessionId ??
        'chat_${now}_${DateTime.now().microsecondsSinceEpoch}';

    int totalQuestions = 0;
    for (final msg in _messages) {
      if (msg.questions != null) totalQuestions += msg.questions!.length;
    }

    final persistedMessages = _messages.map((m) => PersistedChatMessage(
      text: m.text,
      isUser: m.isUser,
      isWelcome: m.isWelcome,
      questions: m.questions
          ?.map((q) => PersistedQuestion(
                id: q.id,
                question: q.question,
                options: q.options,
                correctAnswer: q.correctAnswer,
                explanation: q.explanation,
                modelAnswer: q.modelAnswer,
                maxMarks: q.maxMarks,
                markingPoints: q.markingPoints,
              ))
          .toList(),
    )).toList();

    final session = ChatSession(
      id: sessionId,
      title: '',
      createdAt: _isNewSession ? now : now,
      updatedAt: now,
      messageCount: _messages.length,
      questionCount: totalQuestions,
      messages: persistedMessages,
      source: _source,
      subject: _subject.isNotEmpty ? _subject : null,
      difficulty: _difficulty,
      questionType: _questionType,
      topic: _topicController.text.trim().isNotEmpty
          ? _topicController.text.trim()
          : null,
      documentTitle: _selectedDocument?.title,
    );

    await _historyService.saveSession(session);

    _currentSessionId ??= sessionId;
    _isNewSession = false;
    _loadHistoryList();
  }

  Future<void> _deleteSession(String sessionId) async {
    await _historyService.deleteSession(sessionId);
    if (_currentSessionId == sessionId) {
      setState(() {
        _currentSessionId = null;
        _isNewSession = true;
      });
    }
    _loadHistoryList();
    _showSnackBar('Session deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Image.asset(
                'assets/ai_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text('Alara AI',
                style: context.textStyles.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: _openHistoryDrawer,
              tooltip: 'Chat history',
            ),
          if (_messages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearChat,
              tooltip: 'New conversation',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildAnimatedEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          if (_showInput) _buildInputArea(),
        ],
      ),
    );
  }

  // =========================================================================
  // ANIMATED EMPTY STATE — Rotating Alara AI Robot with Glow
  // =========================================================================

  Widget _buildAnimatedEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated AI Robot logo with glow
            AnimatedBuilder(
              animation: Listenable.merge([_robotPulse, _robotRotate]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _robotPulse.value,
                  child: Transform.rotate(
                    angle: _robotRotate.value * 2 * math.pi,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: LightModeColors.lightSecondary.withValues(alpha: 0.2),
                            blurRadius: 60,
                            spreadRadius: 16,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/ai_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Title
            Text('Alara AI',
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: LightModeColors.lightOnSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text('Generate exam questions with AI',
              style: context.textStyles.bodyMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Start button
            _AnimatedStartButton(
              onTap: () {
                _addMessage('', isUser: false, isWelcome: true);
              },
            ),

            // Recent sessions
            if (_sessions.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 16,
                      color: LightModeColors.lightOnSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Recent Sessions',
                    style: context.textStyles.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._sessions.take(3).map(
                  (session) => _buildRecentSessionCard(session)),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // GENERATING ANIMATION MESSAGE
  // =========================================================================

  Widget _buildGeneratingBubble() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LightModeColors.lightPrimary,
                      LightModeColors.lightSecondary
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    'assets/ai_logo.png',
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('Alara AI',
                style: context.textStyles.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightOnSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _generatingPulseController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing dots
                    ...List.generate(3, (i) {
                      final delay = i * 0.2;
                      final t = (_generatingPulseController.value - delay)
                          .clamp(0.0, 1.0);
                      final size = 8.0 + (t * 6.0);
                      final opacity = 0.3 + (t * 0.7);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: LightModeColors.lightPrimary
                                .withValues(alpha: opacity),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 14),
                    Text(
                      'Generating ${_questionType.replaceAll('_', ' ')} questions...',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HISTORY DRAWER
  // =========================================================================

  void _openHistoryDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _buildHistorySheet(),
    );
  }

  Widget _buildHistorySheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LightModeColors.lightOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.history_rounded,
                        color: LightModeColors.lightPrimary, size: 24),
                    const SizedBox(width: 8),
                    Text('Chat History',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: LightModeColors.lightOnSurface,
                      ),
                    ),
                    const Spacer(),
                    if (_sessions.isNotEmpty)
                      Text(
                        '${_sessions.length} session${_sessions.length == 1 ? '' : 's'}',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Divider(color: LightModeColors.lightOutline.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoadingHistory
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : _sessions.isEmpty
                          ? _buildEmptyHistory()
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: _sessions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                return _buildHistoryItem(_sessions[index]);
                              },
                            ),
                ),
                if (_sessions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Clear All History?'),
                            content: const Text(
                              'This will permanently delete all your chat sessions. This action cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                    foregroundColor:
                                        LightModeColors.lightError),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );
                        if (!mounted || confirm != true) return;
                        await _historyService.clearAll();
                        if (!mounted) return;
                        setState(() => _sessions = []);
                        Navigator.of(this.context).pop();
                        _showSnackBar('All history cleared');
                      },
                      icon: Icon(Icons.delete_sweep_outlined,
                          size: 18, color: LightModeColors.lightError),
                      label: Text('Clear All History',
                        style: context.textStyles.labelMedium
                            ?.copyWith(color: LightModeColors.lightError),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.history_rounded,
                color: LightModeColors.lightPrimary, size: 28),
          ),
          const SizedBox(height: 16),
          Text('No chat history yet',
            style: context.textStyles.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: LightModeColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your generated questions and conversations\nwill appear here',
            textAlign: TextAlign.center,
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ChatSession session) {
    final isActive = session.id == _currentSessionId;
    final icon = session.source == GenerationSource.topic
        ? Icons.edit_note_rounded
        : Icons.description_outlined;

    return Material(
      color: isActive
          ? LightModeColors.lightPrimary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          _openSession(session);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? LightModeColors.lightPrimary.withValues(alpha: 0.15)
                      : LightModeColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                  size: 20,
                  color: isActive
                      ? LightModeColors.lightPrimary
                      : LightModeColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.displayTitle,
                            style: context.textStyles.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.lightOnSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: LightModeColors.lightPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Active',
                              style: context.textStyles.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 12,
                            color: LightModeColors.lightOnSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(session.formattedDate,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.quiz_outlined,
                            size: 12,
                            color: LightModeColors.lightOnSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${session.questionCount} Q',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_outline,
                            size: 12,
                            color: LightModeColors.lightOnSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${session.messageCount} msgs',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Delete Session?'),
                        content: Text(
                            'Delete "${session.displayTitle}"?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor:
                                    LightModeColors.lightError),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (!mounted) return;
                    if (confirm == true) {
                      _deleteSession(session.id);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline,
                        size: 18,
                        color: LightModeColors.lightOnSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // RECENT SESSION CARD
  // =========================================================================

  Widget _buildRecentSessionCard(ChatSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightModeColors.lightOutline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: LightModeColors.lightPrimaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            session.source == GenerationSource.topic
                ? Icons.edit_note_rounded
                : Icons.description_outlined,
            size: 18,
            color: LightModeColors.lightPrimary,
          ),
        ),
        title: Text(session.displayTitle,
          style: context.textStyles.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${session.formattedDate} — ${session.questionCount} question${session.questionCount == 1 ? '' : 's'}',
          style: context.textStyles.bodySmall
              ?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right,
            size: 20, color: LightModeColors.lightOnSurfaceVariant),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        onTap: () => _openSession(session),
      ),
    );
  }

  // =========================================================================
  // MESSAGE BUBBLES
  // =========================================================================

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isGenerating) {
      return _buildGeneratingBubble();
    }

    if (msg.isWelcome) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        LightModeColors.lightPrimary,
                        LightModeColors.lightSecondary
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/ai_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Alara AI',
                  style: context.textStyles.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightOnSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMarkdownText(msg.text),
                  const SizedBox(height: 16),
                  _buildSourceSelector(),
                  const SizedBox(height: 12),
                  if (_source == GenerationSource.document)
                    _buildDocumentPicker(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LightModeColors.lightPrimary,
                LightModeColors.lightSecondary
              ],
            ),
            borderRadius:
                BorderRadius.circular(18).copyWith(bottomRight: Radius.zero),
          ),
          child: _buildMarkdownText(msg.text, isUser: true),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LightModeColors.lightPrimary,
                      LightModeColors.lightSecondary
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    'assets/ai_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('Alara AI',
                style: context.textStyles.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightOnSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMarkdownText(msg.text),
                if (msg.questions != null && msg.questions!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildQuestionActions(msg.questions!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownText(String text, {bool isUser = false}) {
    final lines = text.split('\n');
    final children = <Widget>[];
    final textColor =
        isUser ? Colors.white : LightModeColors.lightOnSurface;

    for (final line in lines) {
      if (line.startsWith('---')) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1),
        ));
        continue;
      }

      String displayLine = line;
      displayLine = displayLine.replaceAllMapped(
          RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
      displayLine = displayLine.replaceAllMapped(
          RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '');

      final isQuote = displayLine.startsWith('> ');
      if (displayLine.trim().isEmpty) {
        children.add(const SizedBox(height: 4));
        continue;
      }

      final isQuestion = RegExp(r'^\*{0,2}Q\d+:\*{0,2}').hasMatch(line);
      final isAnswer = line.contains('**Answer:**');
      final isCorrectOption = line.trimLeft().startsWith('✅');

      TextStyle? style;
      if (isQuestion) {
        style = context.textStyles.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: textColor);
      } else if (isAnswer) {
        style = context.textStyles.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: LightModeColors.accentGreen,
            fontStyle: FontStyle.italic);
      } else if (isCorrectOption) {
        style = context.textStyles.bodyMedium?.copyWith(
            color: LightModeColors.accentGreen,
            fontWeight: FontWeight.w600);
      } else if (isQuote) {
        style = context.textStyles.bodySmall?.copyWith(
            color: isUser
                ? Colors.white.withValues(alpha: 0.9)
                : LightModeColors.lightOnSurfaceVariant,
            fontStyle: FontStyle.italic);
      } else {
        style = context.textStyles.bodyMedium
            ?.copyWith(color: textColor, height: 1.5);
      }

      if (isQuote) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: (isUser
                              ? Colors.white
                              : LightModeColors.lightPrimary)
                          .withValues(alpha: 0.4),
                      width: 3))),
          child: Text(displayLine.replaceFirst('> ', ''), style: style),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(displayLine, style: style),
        ));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children);
  }

  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Generation Method',
          style: context.textStyles.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: LightModeColors.lightOnSurface),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _SourceChip(
              icon: Icons.edit_note_rounded,
              label: 'From Topic',
              isSelected: _source == GenerationSource.topic,
              onTap: () {
                setState(() => _source = GenerationSource.topic);
              },
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _SourceChip(
              icon: Icons.description_outlined,
              label: 'From Material',
              isSelected: _source == GenerationSource.document,
              onTap: () {
                setState(() => _source = GenerationSource.document);
                _loadDocuments(forceRefresh: true);
              },
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Learning Material',
          style: context.textStyles.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: LightModeColors.lightOnSurface),
        ),
        const SizedBox(height: 8),
        if (_isLoadingDocs)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: LightModeColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_off_outlined,
                        color: LightModeColors.lightOnSurfaceVariant, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No learning materials uploaded yet. Upload documents from the Materials section.',
                        style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _loadDocuments(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _loadDocuments(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh list'),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                    border: Border.all(color: LightModeColors.lightOutline),
                    borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _documents.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: LightModeColors.lightOutline),
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final isSelected = _selectedDocument?.id == doc.id;
                    return InkWell(
                      onTap: () => setState(() => _selectedDocument = doc),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isSelected
                                        ? LightModeColors.lightPrimary
                                        : LightModeColors.lightOutline,
                                    width: 2),
                                color: isSelected
                                    ? LightModeColors.lightPrimary
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.description_outlined,
                                color: LightModeColors.lightPrimary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.title,
                                    style: context.textStyles.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (doc.subjectName != null)
                                    Text(doc.subjectName!,
                                      style: context.textStyles.bodySmall
                                          ?.copyWith(
                                              color: LightModeColors
                                                  .lightOnSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildConfigChip(
                        icon: Icons.auto_stories,
                        label: _subject.isNotEmpty ? _subject : 'Subject',
                        onTap: _showSubjectPicker),
                    const SizedBox(width: 6),
                    _buildConfigChip(
                        icon: Icons.tune,
                        label: _difficulty[0].toUpperCase() +
                            _difficulty.substring(1),
                        onTap: _showDifficultyPicker),
                    const SizedBox(width: 6),
                    _buildConfigChip(
                        icon: Icons.quiz_outlined,
                        label: _questionType
                            .replaceAll('_', ' ')
                            .split(' ')
                            .first,
                        onTap: _showQuestionTypePicker),
                    const SizedBox(width: 6),
                    _buildConfigChip(
                        icon: Icons.format_list_numbered,
                        label: '$_numQuestions',
                        onTap: _showNumberPicker),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: LightModeColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: LightModeColors.lightOutline),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.edit_note_rounded,
                              size: 20,
                              color: LightModeColors.lightOnSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _topicController,
                              focusNode: _focusNode,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              style: context.textStyles.bodyMedium?.copyWith(
                                  color: LightModeColors.lightOnSurface),
                              decoration: InputDecoration(
                                hintText: _source == GenerationSource.topic
                                    ? 'e.g., Quadratic Equations, Photosynthesis...'
                                    : 'Optional: add a focus topic...',
                                hintStyle: context.textStyles.bodyMedium
                                    ?.copyWith(
                                        color: LightModeColors
                                            .lightOnSurfaceVariant
                                            .withValues(alpha: 0.6)),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              maxLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _generateQuestions(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          LightModeColors.lightPrimary,
                          LightModeColors.lightSecondary
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: LightModeColors.lightPrimary
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: (_isGenerating ||
                                (_source == GenerationSource.topic &&
                                    _topicController.text.trim().isEmpty) ||
                                (_source == GenerationSource.document &&
                                    _selectedDocument == null))
                            ? null
                            : _generateQuestions,
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigChip(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: LightModeColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LightModeColors.lightOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: LightModeColors.lightPrimary),
            const SizedBox(width: 6),
            Text(label,
              style: context.textStyles.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: LightModeColors.lightOnSurface)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 16, color: LightModeColors.lightOnSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionActions(List<GeneratedQuestion> questions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionButton(
            icon: Icons.copy_all_rounded,
            label: 'Copy All',
            onTap: () => _copyAllQuestions(questions)),
        _ActionButton(
            icon: Icons.file_copy_outlined,
            label: 'Copy as Text',
            onTap: () => _copyAsPlainText(questions)),
      ],
    );
  }

  void _copyAllQuestions(List<GeneratedQuestion> questions) {
    final buf = StringBuffer();
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      buf.writeln('Q${i + 1}: ${q.question}');
      if (q.options != null && q.options!.isNotEmpty) {
        for (final opt in q.options!) {
          buf.writeln('  $opt');
        }
      }
      if (q.correctAnswer != null) {
        buf.writeln('Answer: ${q.correctAnswer}');
      }
      if (q.explanation != null) {
        buf.writeln('Explanation: ${q.explanation}');
      }
      buf.writeln('');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _showSnackBar('All questions copied to clipboard');
  }

  void _copyAsPlainText(List<GeneratedQuestion> questions) {
    final buf = StringBuffer();
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      buf.writeln('Q${i + 1}: ${q.question}');
      if (q.options != null && q.options!.isNotEmpty) {
        for (final opt in q.options!) {
          buf.writeln('  $opt');
        }
      }
      buf.writeln('');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _showSnackBar('Questions (without answers) copied');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  void _showSubjectPicker() {
    final subjects = [
      '',
      'Mathematics',
      'English',
      'Physics',
      'Chemistry',
      'Biology',
      'History',
      'Geography',
      'ICT',
      'French',
      'Social Studies',
      'Religious Studies'
    ];
    _showPickerSheet(
      title: 'Select Subject',
      items: subjects
          .map((s) => _PickerItem(
              label: s.isEmpty ? 'None' : s,
              value: s,
              isSelected: _subject == s))
          .toList(),
      onSelect: (value) {
        setState(() => _subject = value as String);
        Navigator.pop(context);
      },
    );
  }

  void _showDifficultyPicker() {
    _showPickerSheet(
      title: 'Select Difficulty',
      items: ['easy', 'medium', 'hard']
          .map((d) => _PickerItem(
              label: d[0].toUpperCase() + d.substring(1),
              value: d,
              isSelected: _difficulty == d))
          .toList(),
      onSelect: (value) {
        setState(() => _difficulty = value as String);
        Navigator.pop(context);
      },
    );
  }

  void _showQuestionTypePicker() {
    final labels = {
      'multiple_choice': 'Multiple Choice',
      'short_answer': 'Short Answer',
      'essay': 'Essay'
    };
    _showPickerSheet(
      title: 'Select Question Type',
      items: ['multiple_choice', 'short_answer', 'essay']
          .map((t) => _PickerItem(
              label: labels[t] ?? t,
              value: t,
              isSelected: _questionType == t))
          .toList(),
      onSelect: (value) {
        setState(() => _questionType = value as String);
        Navigator.pop(context);
      },
    );
  }

  void _showNumberPicker() {
    _showPickerSheet(
      title: 'Number of Questions',
      items: List.generate(10, (i) {
        final n = i + 1;
        return _PickerItem(
            label: '$n ${n == 1 ? "question" : "questions"}',
            value: n,
            isSelected: _numQuestions == n);
      }),
      onSelect: (value) {
        setState(() => _numQuestions = value as int);
        Navigator.pop(context);
      },
    );
  }

  void _showPickerSheet(
      {required String title,
      required List<_PickerItem> items,
      required Function(dynamic) onSelect}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LightModeColors.lightOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title,
                  style: context.textStyles.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        leading: item.isSelected
                            ? Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: LightModeColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 16),
                              )
                            : Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: LightModeColors.lightOutline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                        title: Text(item.label,
                          style: context.textStyles.bodyMedium?.copyWith(
                              fontWeight: item.isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                        onTap: () => onSelect(item.value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isWelcome;
  final bool isGenerating;
  final List<GeneratedQuestion>? questions;

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.isWelcome = false,
    this.isGenerating = false,
    this.questions,
  });
}

class _PickerItem {
  final String label;
  final dynamic value;
  final bool isSelected;
  _PickerItem(
      {required this.label, required this.value, this.isSelected = false});
}

// =========================================================================
// ANIMATED START BUTTON with glow
// =========================================================================

class _AnimatedStartButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedStartButton({required this.onTap});

  @override
  State<_AnimatedStartButton> createState() => _AnimatedStartButtonState();
}

class _AnimatedStartButtonState extends State<_AnimatedStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: widget.onTap,
              icon: const Icon(Icons.rocket_launch_outlined, size: 20),
              label: const Text('Start Generating'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceChip(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? LightModeColors.lightPrimary.withValues(alpha: 0.1)
              : LightModeColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? LightModeColors.lightPrimary
                  : LightModeColors.lightOutline,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? LightModeColors.lightPrimary
                    : LightModeColors.lightOnSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
              style: context.textStyles.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? LightModeColors.lightPrimary
                    : LightModeColors.lightOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: context.textStyles.labelMedium),
      style: TextButton.styleFrom(
        foregroundColor: LightModeColors.lightPrimary,
        backgroundColor: LightModeColors.lightPrimary.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
