import 'package:flutter/material.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/services/chat_history_service.dart';
import 'package:alara/theme.dart';

class StudentAiAssistantScreen extends StatefulWidget {
  const StudentAiAssistantScreen({super.key});

  @override
  State<StudentAiAssistantScreen> createState() => _StudentAiAssistantScreenState();
}

class _StudentAiAssistantScreenState extends State<StudentAiAssistantScreen> {
  final StudentService _service = StudentService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final ChatHistoryService _historyService = ChatHistoryService();

  final List<_StudentAiMessage> _messages = [];
  List<Map<String, dynamic>> _materials = [];
  List<ChatSession> _sessions = [];
  bool _isSending = false;
  bool _isLoadingMaterials = false;
  bool _isLoadingHistory = false;
  String? _selectedMaterialId;
  String _questionType = 'short_answer';
  int _numQuestions = 3;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _StudentAiMessage(
        text: 'Hi! I am your AI study assistant. Ask me about assignments, materials, or revision help.',
        isUser: false,
        isWelcome: true,
      ),
    );
    _loadMaterials();
    _loadHistoryList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoadingMaterials = true);
    final materials = await _service.getMaterials();
    if (!mounted) return;
    setState(() {
      _materials = materials;
      _isLoadingMaterials = false;
    });
  }

  Future<void> _loadHistoryList() async {
    setState(() => _isLoadingHistory = true);
    final sessions = await _historyService.loadSessionList();
    if (!mounted) return;
    setState(() {
      _sessions = sessions.where((s) => s.id.startsWith('student_ai_')).toList();
      _isLoadingHistory = false;
    });
  }

  Future<void> _saveSession() async {
    if (_messages.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _sessionId ?? 'student_ai_$now';

    final persistedMessages = _messages
        .map((m) => PersistedChatMessage(
              text: m.text,
              isUser: m.isUser,
              isWelcome: m.isWelcome,
            ))
        .toList();

    final title = _messages.firstWhere(
      (m) => m.isUser && m.text.trim().isNotEmpty,
      orElse: () => _StudentAiMessage(text: 'Student AI Session', isUser: false),
    ).text;

    final session = ChatSession(
      id: id,
      title: title.length > 50 ? '${title.substring(0, 50)}...' : title,
      createdAt: _sessionId == null ? now : (_sessions.firstWhere((s) => s.id == _sessionId, orElse: () => ChatSession(id: id, title: 'Student AI Session', createdAt: now, updatedAt: now)).createdAt),
      updatedAt: now,
      messageCount: persistedMessages.length,
      questionCount: 0,
      messages: persistedMessages,
      source: GenerationSource.topic,
      questionType: _questionType,
    );

    await _historyService.saveSession(session);
    _sessionId = id;
    await _loadHistoryList();
  }

  Future<void> _send() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_StudentAiMessage(text: prompt, isUser: true));
      _messages.add(_StudentAiMessage(text: 'Thinking...', isUser: false, isTyping: true));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await _service.askStudentAi(
      prompt: prompt,
      contextId: _selectedMaterialId,
      questionType: _questionType,
      numQuestions: _numQuestions,
    );

    if (!mounted) return;

    setState(() {
      if (_messages.isNotEmpty && _messages.last.isTyping) {
        _messages.removeLast();
      }
      _messages.add(
        _StudentAiMessage(
          text: response.success
              ? response.message
              : (response.error ?? 'I could not respond right now. Please try again.'),
          isUser: false,
        ),
      );
      _isSending = false;
    });

    await _saveSession();
    _scrollToBottom();
  }

  Future<void> _generateFromMaterial() async {
    if (_selectedMaterialId == null || _selectedMaterialId!.isEmpty || _isSending) return;
    final material = _materials.firstWhere(
      (m) => (m['id']?.toString() ?? '') == _selectedMaterialId,
      orElse: () => <String, dynamic>{},
    );
    final title = (material['title']?.toString().trim().isNotEmpty ?? false)
        ? material['title'].toString()
        : 'Selected material';

    _controller.text = 'Generate practice questions from "$title"';
    await _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Student AI Assistant', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistorySheet,
          ),
        ],
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMaterialId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Learning Material (optional)',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _materials.map((m) {
                          final id = m['id']?.toString() ?? '';
                          final title = (m['title']?.toString().trim().isNotEmpty ?? false)
                              ? m['title'].toString()
                              : 'Material $id';
                          return DropdownMenuItem(
                            value: id,
                            child: Text(title, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _isLoadingMaterials
                            ? null
                            : (value) => setState(() => _selectedMaterialId = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: (_selectedMaterialId == null || _isSending)
                          ? null
                          : _generateFromMaterial,
                      icon: const Icon(Icons.quiz_rounded),
                      label: const Text('Generate'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'short_answer', label: Text('Short')),
                          ButtonSegment(value: 'multiple_choice', label: Text('MCQ')),
                        ],
                        selected: {_questionType},
                        onSelectionChanged: (v) {
                          if (v.isNotEmpty) {
                            setState(() => _questionType = v.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _numQuestions,
                      items: const [1, 3, 5, 10]
                          .map((n) => DropdownMenuItem(value: n, child: Text('$n Qs')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _numQuestions = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final align = m.isUser ? Alignment.centerRight : Alignment.centerLeft;
                final bg = m.isUser ? LightModeColors.lightPrimary : Colors.white;
                final fg = m.isUser ? Colors.white : LightModeColors.lightOnSurface;
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: m.isTyping
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(m.text, style: TextStyle(color: fg)),
                            ],
                          )
                        : Text(m.text, style: TextStyle(color: fg)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isSending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask a question about your studies...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: LightModeColors.lightOutline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: LightModeColors.lightOutline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text('Search History', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _sessions.isEmpty
                        ? const Center(child: Text('No history yet'))
                        : ListView.builder(
                            itemCount: _sessions.length,
                            itemBuilder: (_, i) {
                              final s = _sessions[i];
                              return ListTile(
                                leading: const Icon(Icons.history_rounded),
                                title: Text(s.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(s.formattedDate),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () async {
                                    await _historyService.deleteSession(s.id);
                                    if (!mounted) return;
                                    await _loadHistoryList();
                                  },
                                ),
                                onTap: () async {
                                  final all = await _historyService.loadSessions();
                                  ChatSession? full;
                                  for (final x in all) {
                                    if (x.id == s.id) {
                                      full = x;
                                      break;
                                    }
                                  }
                                  final selected = full;
                                  if (selected == null) return;
                                  if (!mounted) return;
                                  setState(() {
                                    _sessionId = selected.id;
                                    _messages
                                      ..clear()
                                      ..addAll(selected.messages.map((m) => _StudentAiMessage(
                                            text: m.text,
                                            isUser: m.isUser,
                                            isWelcome: m.isWelcome,
                                          )));
                                  });
                                  Navigator.of(ctx).pop();
                                  _scrollToBottom();
                                },
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: _sessions.isEmpty
                      ? null
                      : () async {
                          await _historyService.clearAll();
                          if (!mounted) return;
                          await _loadHistoryList();
                        },
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Clear All'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentAiMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final bool isWelcome;

  _StudentAiMessage({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.isWelcome = false,
  });
}
