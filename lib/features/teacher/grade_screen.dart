import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alara/services/grading_service.dart';
import 'package:alara/services/terminal_report_service.dart';
import 'package:alara/core/models/grade_model.dart';
import 'package:alara/core/models/assessment_model.dart';
import 'package:alara/theme.dart';

/// Category options for assessments
const List<Map<String, String>> categoryOptions = [
  {'value': 'continuous_assessment', 'label': 'Continuous Assessment'},
  {'value': 'examination', 'label': 'Examination'},
];

class GradeScreen extends StatefulWidget {
  const GradeScreen({super.key});

  @override
  State<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  final GradingService _service = GradingService();

  // =======================================================================
  // STATE
  // =======================================================================

  // Core data
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sessions = [];
  GradeEntryData? _entryData;
  AssessmentsByCategory? _assessments;

  // Selection state
  int? _selectedClassId;
  int? _selectedSubjectId;
  int? _selectedSessionId;
  int? _selectedTerm;
  Assessment? _selectedAssessment;
  String _selectedCategory = 'continuous_assessment';

  // Score entry state
  AssessmentScoresResponse? _scoreData;
  final Map<String, TextEditingController> _scoreControllers = {};
  bool _hasUnsavedChanges = false;

  // Computed results state
  ComputedResults? _computedResults;

  // Class-wide terminal report results (positions, grading system, promotion, etc.)
  TerminalReportsData? _classReportsData;

  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isComputing = false;

  // UI mode: 'entry' or 'results'
  String _uiMode = 'entry';

  // Which detailed results sub-tab
  String _resultsTab = 'positions'; // 'positions', 'grading', 'summary'

  // Expanded student detail in terminal reports
  int? _expandedStudentId;

  // Create assessment dialog state
  final _createTitleController = TextEditingController();
  final _createTotalMarksController = TextEditingController(text: '100');
  final _createWeightController = TextEditingController(text: '10');
  DateTime _createDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadSessions();
  }

  @override
  void dispose() {
    _createTitleController.dispose();
    _createTotalMarksController.dispose();
    _createWeightController.dispose();
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // =======================================================================
  // DATA LOADING
  // =======================================================================

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final classes = await _service.getTeacherClasses();
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
          if (classes.isNotEmpty && _selectedClassId == null) {
            _selectedClassId = int.tryParse(classes.first['id'].toString());
            _loadEntryData();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _service.getAcademicSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          // Auto-select current session
          final current = sessions.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['is_current'] == true,
            orElse: () => sessions.isNotEmpty ? sessions.first : null,
          );
          if (current != null) {
            _selectedSessionId = int.tryParse(current['id'].toString());
            _selectedTerm = current['term'] as int? ?? 1;
          }
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadEntryData() async {
    if (_selectedClassId == null) return;

    setState(() {
      _isLoading = true;
      _entryData = null;
      _assessments = null;
      _scoreData = null;
      _selectedSubjectId = null;
      _selectedAssessment = null;
      _computedResults = null;
      _classReportsData = null;
      _scoreControllers.clear();
    });

    try {
      final data = await _service.getGradeEntryData(_selectedClassId!);
      if (mounted) {
        setState(() {
          _entryData = data;
          _isLoading = false;
          if (data != null && data.subjects.isNotEmpty) {
            _selectedSubjectId = data.subjects.first.id;
            _loadAssessments();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssessments() async {
    if (_selectedClassId == null || _selectedSubjectId == null) return;

    try {
      final result = await _service.getAssessmentsForClassSubject(
        classId: _selectedClassId!,
        subjectId: _selectedSubjectId!,
        term: _selectedTerm,
        academicSessionId: _selectedSessionId,
      );

      if (mounted) {
        setState(() {
          _assessments = result;
          _selectedAssessment = null;
          _scoreData = null;
          _computedResults = null;
          _scoreControllers.clear();
        });
      }
    } catch (e) {
      debugPrint('Load assessments error: $e');
    }
  }

  Future<void> _loadScores() async {
    if (_selectedAssessment == null) return;

    try {
      final data = await _service.getAssessmentScores(_selectedAssessment!.id);
      if (mounted) {
        setState(() {
          _scoreData = data;
          _hasUnsavedChanges = false;

          // Populate score controllers
          _scoreControllers.clear();
          if (data != null) {
            for (final student in data.students) {
              final key = student.studentId.toString();
              _scoreControllers[key] = TextEditingController(
                text: student.score?.toStringAsFixed(0) ?? '',
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Load scores error: $e');
    }
  }

  // =======================================================================
  // COMPUTATION
  // =======================================================================

  Future<void> _computeResults() async {
    if (_selectedClassId == null || _selectedSubjectId == null) return;

    setState(() => _isComputing = true);

    try {
      // Get per-subject computed results
      final results = await _service.computeResults(
        classId: _selectedClassId!,
        subjectId: _selectedSubjectId!,
        academicSessionId: _selectedSessionId,
        term: _selectedTerm,
      );

      // Get class-wide terminal report data (grading system, positions, promotion)
      TerminalReportsData? classData;
      try {
        classData = await _service.getClassTerminalReports(
          classId: _selectedClassId!,
          sessionId: _selectedSessionId,
        );
      } catch (_) {
        // Non-critical; class data may not be computed yet
      }

      if (mounted) {
        setState(() {
          _computedResults = results;
          _classReportsData = classData;
          _isComputing = false;
          _expandedStudentId = null;
          if (results != null) _uiMode = 'results';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isComputing = false);
    }
  }

  Future<void> _computeClassWideReports() async {
    if (_selectedClassId == null || _selectedSessionId == null) return;

    setState(() => _isComputing = true);

    try {
      await _service.computeClassTerminalReports(
        classId: _selectedClassId!,
        sessionId: _selectedSessionId!,
      );

      // Reload class-wide data
      final classData = await _service.getClassTerminalReports(
        classId: _selectedClassId!,
        sessionId: _selectedSessionId!,
      );

      if (mounted) {
        setState(() {
          _classReportsData = classData;
          _isComputing = false;
          _showSnackBar('Class reports computed successfully', isError: false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isComputing = false);
        _showSnackBar('Failed to compute class reports: $e', isError: true);
      }
    }
  }

  // =======================================================================
  // ACTIONS
  // =======================================================================

  Future<void> _saveAllScores() async {
    if (_selectedAssessment == null || _scoreData == null) return;

    setState(() => _isSubmitting = true);

    final scores = <ScoreEntry>[];
    for (final student in _scoreData!.students) {
      final key = student.studentId.toString();
      final text = _scoreControllers[key]?.text.trim() ?? '';
      if (text.isEmpty) continue;

      final score = double.tryParse(text);
      if (score == null) continue;

      scores.add(ScoreEntry(
        studentId: student.studentId,
        studentName: student.studentName,
        score: score.clamp(0, _selectedAssessment!.totalMarks),
      ));
    }

    if (scores.isEmpty) {
      setState(() => _isSubmitting = false);
      _showSnackBar('No scores to submit', isError: true);
      return;
    }

    final result = await _service.bulkSaveScores(
      assessmentId: _selectedAssessment!.id,
      scores: scores,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result.errorCount == 0) {
        _showSnackBar(
          '${result.successCount} scores saved successfully',
          isError: false,
        );
        setState(() => _hasUnsavedChanges = false);
        _loadScores();
      } else {
        _showSnackBar(
          '${result.successCount} saved, ${result.errorCount} failed',
          isError: true,
        );
      }
    }
  }

  void _showCreateAssessmentDialog() {
    _createTitleController.clear();
    _createTotalMarksController.text = '100';
    _createWeightController.text = '10';
    _createDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Assessment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _createTitleController,
                decoration: const InputDecoration(
                  labelText: 'Assessment Title *',
                  hintText: 'e.g., First Term Continuous Assessment',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: categoryOptions.map((opt) {
                  return DropdownMenuItem(
                    value: opt['value'],
                    child: Text(opt['label']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _selectedCategory = val;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _createTotalMarksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Marks *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _createWeightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight %',
                        hintText: 'e.g., 10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _createDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) _createDate = picked;
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Assessment Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_createDate.year}-${_createDate.month.toString().padLeft(2, '0')}-${_createDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitCreateAssessment(ctx),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreateAssessment(BuildContext dialogContext) async {
    if (_createTitleController.text.trim().isEmpty) {
      _showSnackBar('Title is required', isError: true);
      return;
    }

    final totalMarks = double.tryParse(_createTotalMarksController.text) ?? 100;
    final weight = double.tryParse(_createWeightController.text) ?? 0;

    final dateStr =
        '${_createDate.year}-${_createDate.month.toString().padLeft(2, '0')}-${_createDate.day.toString().padLeft(2, '0')}';

    final data = {
      'title': _createTitleController.text.trim(),
      'subject': _selectedSubjectId,
      'class_obj': _selectedClassId,
      'academic_session': _selectedSessionId,
      'term': _selectedTerm ?? 1,
      'category': _selectedCategory,
      'total_marks': totalMarks,
      'assessment_date': dateStr,
      'weight_percentage': weight,
    };

    final result = await _service.createAssessment(data);
    if (mounted) {
      Navigator.pop(dialogContext);
      if (result != null) {
        _showSnackBar('Assessment created successfully', isError: false);
        _loadAssessments();
      } else {
        _showSnackBar('Failed to create assessment', isError: true);
      }
    }
  }

  void _onScoreChanged(String studentId, String value) {
    setState(() => _hasUnsavedChanges = true);
  }

  // =======================================================================
  // SNACKBAR
  // =======================================================================

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? LightModeColors.lightError : LightModeColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  // =======================================================================
  // BUILD
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: Text(
          _uiMode == 'results' ? 'Computed Results' : 'Grading',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
    );
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    if (_hasUnsavedChanges) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: LightModeColors.accentOrange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    if (_uiMode == 'results' && _computedResults != null) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: () => setState(() => _uiMode = 'entry'),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Back to Entry'),
          ),
        ),
      );
    }

    if (_uiMode == 'entry' && _selectedAssessment != null && _scoreData != null) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : _saveAllScores,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(_isSubmitting ? 'Saving...' : 'Save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: LightModeColors.lightPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    }

    return actions;
  }

  Widget _buildBody() {
    if (_isLoading && _classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classes.isEmpty) {
      return _buildEmptyState('No classes assigned to you.', Icons.school_outlined);
    }

    return Column(
      children: [
        // Filters + assessment selector
        _buildFilterBar(),
        // Main content area
        Expanded(child: _buildContent()),
      ],
    );
  }

  // =======================================================================
  // FILTER BAR
  // =======================================================================

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Class + Subject
          Row(
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Class',
                  value: _selectedClassId?.toString(),
                  items: _classes.map((c) {
                    return DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name'] ?? 'Class', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedClassId = val != null ? int.tryParse(val) : null;
                      _selectedSubjectId = null;
                      _selectedAssessment = null;
                      _computedResults = null;
                      _classReportsData = null;
                    });
                    if (_selectedClassId != null) _loadEntryData();
                  },
                  icon: Icons.school_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField(
                  label: 'Subject',
                  value: _selectedSubjectId?.toString(),
                  items: (_entryData?.subjects ?? []).map((s) {
                    return DropdownMenuItem(
                      value: s.id.toString(),
                      child: Text(s.name, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubjectId = val != null ? int.tryParse(val) : null;
                      _selectedAssessment = null;
                      _computedResults = null;
                      _classReportsData = null;
                    });
                    if (_selectedSubjectId != null) _loadAssessments();
                  },
                  icon: Icons.book_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Session + Term
          Row(
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Session',
                  value: _selectedSessionId?.toString(),
                  items: _sessions.map((s) {
                    return DropdownMenuItem(
                      value: s['id'].toString(),
                      child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSessionId = val != null ? int.tryParse(val) : null;
                      final session = _sessions.cast<Map<String, dynamic>?>().firstWhere(
                        (s) => s?['id'].toString() == val,
                        orElse: () => null,
                      );
                      _selectedTerm = session?['term'] as int? ?? _selectedTerm;
                      _selectedAssessment = null;
                      _computedResults = null;
                      _classReportsData = null;
                    });
                    if (_selectedSubjectId != null) _loadAssessments();
                  },
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField(
                  label: 'Term',
                  value: _selectedTerm?.toString(),
                  items: [1, 2, 3].map((t) {
                    return DropdownMenuItem(
                      value: t.toString(),
                      child: Text('Term $t', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTerm = val != null ? int.tryParse(val) : 1;
                      _selectedAssessment = null;
                      _computedResults = null;
                      _classReportsData = null;
                    });
                    if (_selectedSubjectId != null) _loadAssessments();
                  },
                  icon: Icons.format_list_numbered_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 3: Assessment selector + actions
          Row(
            children: [
              Expanded(
                child: _buildAssessmentSelector(),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _showCreateAssessmentDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightModeColors.lightPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 4: Category + action buttons
          Row(
            children: [
              // Category filter for entry mode
              if (_uiMode == 'entry')
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categoryOptions.map((opt) {
                        final isSelected = _selectedCategory == opt['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedCategory = opt['value']!);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? LightModeColors.lightPrimary
                                    : LightModeColors.lightSurfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                opt['label']!.split(' ').first,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : LightModeColors.lightOnSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              if (_uiMode == 'entry') const SizedBox(width: 8),
              // Compute Results button
              OutlinedButton.icon(
                onPressed: _isComputing ? null : _computeResults,
                icon: _isComputing
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_rounded, size: 16),
                label: Text(
                  _isComputing ? 'Computing...' : 'Results',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 6),
              // Compute class-wide reports button
              OutlinedButton.icon(
                onPressed: (_isComputing || _selectedSessionId == null)
                    ? null
                    : _computeClassWideReports,
                icon: _isComputing
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_work_rounded, size: 16),
                label: Text(
                  _isComputing ? '...' : 'Class Reports',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentSelector() {
    final allAssessments = _assessments?.all ?? [];

    if (allAssessments.isEmpty) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LightModeColors.lightBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.4)),
        ),
        alignment: Alignment.centerLeft,
        child: const Text(
          'No assessments yet - tap New',
          style: TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant),
        ),
      );
    }

    return _DropdownField(
      label: 'Select Assessment',
      value: _selectedAssessment?.id.toString(),
      items: allAssessments.map((a) {
        final icon = a.category == 'continuous_assessment'
            ? Icons.assignment_rounded
            : Icons.quiz_rounded;
        return DropdownMenuItem(
          value: a.id.toString(),
          child: Row(
            children: [
              Icon(icon, size: 14, color: LightModeColors.lightOnSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.title,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: a.category == 'examination'
                      ? LightModeColors.accentOrange.withOpacity(0.15)
                      : LightModeColors.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  a.category == 'examination' ? 'Exam' : 'CA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: a.category == 'examination'
                        ? LightModeColors.accentOrange
                        : LightModeColors.accentGreen,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          final assessment = allAssessments.cast<Assessment?>().firstWhere(
            (a) => a?.id.toString() == val,
            orElse: () => null,
          );
          setState(() {
            _selectedAssessment = assessment;
            _computedResults = null;
          });
          if (_selectedAssessment != null) {
            _loadScores();
          }
        } else {
          setState(() {
            _selectedAssessment = null;
            _scoreData = null;
          });
        }
      },
      icon: Icons.assignment_rounded,
    );
  }

  // =======================================================================
  // CONTENT
  // =======================================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_computedResults != null && _uiMode == 'results') {
      return _buildResultsView();
    }

    if (_selectedAssessment == null) {
      if (_assessments == null) {
        return _buildEmptyState('Select a class and subject.', Icons.touch_app_rounded);
      }
      if (_assessments!.all.isEmpty) {
        return _buildEmptyState(
          'No assessments yet. Create one to start grading.',
          Icons.note_add_outlined,
        );
      }
      return _buildEmptyState('Select an assessment to enter scores.', Icons.assignment_rounded);
    }

    if (_scoreData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildScoreEntryView();
  }

  // =======================================================================
  // SCORE ENTRY VIEW
  // =======================================================================

  Widget _buildScoreEntryView() {
    final students = _scoreData!.students;
    final graded = _scoreData!.gradedCount;

    if (students.isEmpty) {
      return _buildEmptyState('No students in this class.', Icons.people_outline);
    }

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: LightModeColors.lightSurfaceVariant,
          child: Row(
            children: [
              Text(
                '${students.length} students • $graded graded',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Max: ${_selectedAssessment!.totalMarks.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightPrimary,
                ),
              ),
            ],
          ),
        ),
        // Student rows
        Expanded(
          child: _buildStudentScoreList(students),
        ),
      ],
    );
  }

  Widget _buildStudentScoreList(List<StudentScoreEntry> students) {
    return RefreshIndicator(
      onRefresh: _loadScores,
      color: LightModeColors.lightPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: students.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) return _buildScoreTableHeader();
          final student = students[index - 1];
          return _buildStudentScoreRow(student, index);
        },
      ),
    );
  }

  Widget _buildScoreTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant))),
          const SizedBox(width: 8),
          Expanded(child: Text('Student', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant))),
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            child: Text(
              'Score / ${_selectedAssessment?.totalMarks.toStringAsFixed(0) ?? ''}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentScoreRow(StudentScoreEntry student, int index) {
    final key = student.studentId.toString();
    final controller = _scoreControllers[key];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: student.hasScore
            ? Border.all(color: LightModeColors.accentGreen.withOpacity(0.2), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 24,
              child: Text(
                '$index',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: LightModeColors.lightOnSurfaceVariant),
              ),
            ),
            // Avatar
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LightModeColors.lightPrimary.withOpacity(0.7),
                    LightModeColors.lightSecondary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getInitials(student.studentName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (student.hasScore && student.gradeLetter != null && student.gradeLetter!.isNotEmpty)
                    Text(
                      '${student.gradeLetter} • ${student.score?.toStringAsFixed(0) ?? '-'} pts',
                      style: TextStyle(
                        fontSize: 10,
                        color: student.hasScore
                            ? LightModeColors.accentGreen
                            : LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // Score input
            SizedBox(
              width: 80,
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
                  ],
                  decoration: InputDecoration(
                    hintText: '-',
                    hintStyle: TextStyle(
                      color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: LightModeColors.lightOutline.withOpacity(0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: LightModeColors.lightOutline.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  onChanged: (value) => _onScoreChanged(key, value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // RESULTS VIEW (grading system, positions, promotion display)
  // =======================================================================

  Widget _buildResultsView() {
    return Column(
      children: [
        // Tabs for results sections
        _buildResultsTabBar(),
        // Content based on selected tab
        Expanded(child: _buildResultsTabContent()),
      ],
    );
  }

  Widget _buildResultsTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabChip(
              label: 'Positions',
              icon: Icons.leaderboard_rounded,
              isSelected: _resultsTab == 'positions',
              onTap: () => setState(() => _resultsTab = 'positions'),
            ),
            const SizedBox(width: 6),
            _TabChip(
              label: 'Grading System',
              icon: Icons.grading_rounded,
              isSelected: _resultsTab == 'grading',
              onTap: () => setState(() => _resultsTab = 'grading'),
            ),
            const SizedBox(width: 6),
            _TabChip(
              label: 'Class Summary',
              icon: Icons.analytics_rounded,
              isSelected: _resultsTab == 'summary',
              onTap: () => setState(() => _resultsTab = 'summary'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTabContent() {
    switch (_resultsTab) {
      case 'grading':
        return _buildGradingSystemView();
      case 'summary':
        return _buildClassSummaryView();
      case 'positions':
      default:
        return _buildPositionsView();
    }
  }

  // =======================================================================
  // GRADING SYSTEM TAB - shows grade boundaries and exam types
  // =======================================================================

  Widget _buildGradingSystemView() {
    final gradingSystem = _classReportsData?.gradingSystem;
    final hasAssessments = (_classReportsData?.continuousAssessments.isNotEmpty ?? false) ||
        (_classReportsData?.examinations.isNotEmpty ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grading Scale section
          if (gradingSystem != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.grading_rounded, color: LightModeColors.lightPrimary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grading System',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            Text(
                              gradingSystem.name + (gradingSystem.isDefault ? ' (Default)' : ''),
                              style: const TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Grade boundaries table
                  Container(
                    decoration: BoxDecoration(
                      color: LightModeColors.lightBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimary.withOpacity(0.08),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(width: 28, child: Text('Grade', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                              Expanded(child: Text('Range', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                              Expanded(child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                            ],
                          ),
                        ),
                        // Table rows
                        ...gradingSystem.entries.map((entry) {
                          final color = entry.promotionEligible ? LightModeColors.accentGreen : LightModeColors.lightError;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: LightModeColors.lightOutline.withOpacity(0.3)),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      entry.gradeLetter,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${entry.minPercentage.toStringAsFixed(0)}% - ${entry.maxPercentage.toStringAsFixed(0)}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        entry.promotionEligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                        size: 14,
                                        color: color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        entry.promotionEligible ? 'Promote' : 'Repeat',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (gradingSystem.entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No grade boundaries configured', style: TextStyle(color: LightModeColors.lightOnSurfaceVariant, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (gradingSystem == null && hasAssessments) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: LightModeColors.accentOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.grading_rounded, color: LightModeColors.accentOrange, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Grading System', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No grading system configured for this session yet. '
                    'School administrators can set up grade boundaries in the Grading Scales section.',
                    style: TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Continuous Assessments section
          if (_classReportsData?.continuousAssessments.isNotEmpty ?? false) ...[
            const Text(
              'Continuous Assessments',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ..._classReportsData!.continuousAssessments.map((a) => _assessmentCard(a, LightModeColors.accentBlue)),
            const SizedBox(height: 16),
          ],

          // Examinations section
          if (_classReportsData?.examinations.isNotEmpty ?? false) ...[
            const Text(
              'Examinations',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ..._classReportsData!.examinations.map((a) => _assessmentCard(a, LightModeColors.accentOrange)),
            const SizedBox(height: 16),
          ],

          if (gradingSystem == null && !hasAssessments)
            _buildEmptyState(
              'Tap "Class Reports" to load grading system and exam types.',
              Icons.info_outline_rounded,
            ),
        ],
      ),
    );
  }

  Widget _assessmentCard(AssessmentTypeInfo a, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              a.category == 'examination' ? Icons.quiz_rounded : Icons.assignment_rounded,
              color: color, size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${a.totalMarks.toStringAsFixed(0)} marks • ${a.weightPercentage.toStringAsFixed(0)}% weight',
                  style: const TextStyle(fontSize: 11, color: LightModeColors.lightOnSurfaceVariant),
                ),
              ],
            ),
          ),
          if (a.subjectName != null && a.subjectName!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                a.subjectName!,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ),
        ],
      ),
    );
  }

  // =======================================================================
  // CLASS SUMMARY TAB - overall average, best student, best subject, promotion status
  // =======================================================================

  Widget _buildClassSummaryView() {
    final summary = _classReportsData?.summary;
    final subjResults = _computedResults;

    if (summary == null && subjResults == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 48, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.35)),
              const SizedBox(height: 12),
              const Text(
                'Tap "Results" or "Class Reports" to compute summaries.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: LightModeColors.lightOnSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Average & Grade
          if (summary != null)
            _buildSummaryCard(
              icon: Icons.analytics_rounded,
              title: 'Class Overall Average',
              value: '${summary.averageScore.toStringAsFixed(1)}%',
              color: LightModeColors.lightPrimary,
              subtitle: '${summary.totalStudents} students',
            ),
          if (summary != null) const SizedBox(height: 12),

          // Subject-level summary from computed results
          if (subjResults != null)
            _buildSummaryCard(
              icon: Icons.book_rounded,
              title: 'Subject Average (${_getSelectedSubjectName()})',
              value: '${subjResults.summary.averageScore.toStringAsFixed(1)}%',
              color: LightModeColors.accentBlue,
              subtitle: 'Highest: ${subjResults.summary.highestScore.toStringAsFixed(1)}% • Lowest: ${subjResults.summary.lowestScore.toStringAsFixed(1)}%',
            ),
          if (subjResults != null) const SizedBox(height: 12),

          // Best Student
          if (summary?.bestStudentName != null)
            _buildPersonCard(
              icon: Icons.emoji_events_rounded,
              title: 'Best Student',
              name: summary!.bestStudentName!,
              score: summary.bestStudentScore,
              color: LightModeColors.accentOrange,
              subtitle: 'Class Leader',
            ),
          if (summary?.bestStudentName != null) const SizedBox(height: 12),

          // Best Subject
          if (summary?.bestSubjectName != null && summary!.bestSubjectName!.isNotEmpty)
            _buildSummaryCard(
              icon: Icons.star_rounded,
              title: 'Best Subject',
              value: summary.bestSubjectName!,
              color: LightModeColors.accentGreen,
              subtitle: 'Score: ${summary.bestSubjectScore.toStringAsFixed(1)}%',
            ),
          if (summary?.bestSubjectName != null && summary!.bestSubjectName!.isNotEmpty)
            const SizedBox(height: 12),

          // Promotion & Repeat stats
          if (summary != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: LightModeColors.accentGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.trending_up_rounded, color: LightModeColors.accentGreen, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Promotion Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _MiniStatBox(
                        icon: Icons.check_circle_rounded,
                        label: 'Promoted',
                        value: '${summary.studentsPromoted}',
                        color: LightModeColors.accentGreen,
                      ),
                      const SizedBox(width: 8),
                      _MiniStatBox(
                        icon: Icons.cancel_rounded,
                        label: 'Repeated',
                        value: '${summary.studentsRepeated}',
                        color: summary.studentsRepeated > 0 ? LightModeColors.lightError : LightModeColors.accentGreen,
                      ),
                    ],
                  ),
                  if (summary.totalStudents > 0) ...[
                    const SizedBox(height: 10),
                    // Progress bar showing ratio
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.studentsPromoted / summary.totalStudents,
                        backgroundColor: LightModeColors.lightError.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(LightModeColors.accentGreen),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.studentsPromoted}/${summary.totalStudents} students promoted (${(summary.studentsPromoted / summary.totalStudents * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 11, color: LightModeColors.lightOnSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Student positions list
          if (_classReportsData?.reports.isNotEmpty ?? false) ...[
            const Text(
              'Student Rankings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ..._classReportsData!.reports.map((r) => _buildReportRow(r)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: LightModeColors.lightOnSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard({
    required IconData icon,
    required String title,
    required String name,
    required double score,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ],
                Text(
                  'Score: ${score.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: LightModeColors.lightOnSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#1',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(StudentTerminalReport report) {
    final gradeColor = _gradeColor(report.grade);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Position
          Container(
            width: 30,
            child: Text(
              report.positionText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: report.position != null && report.position! <= 3
                    ? LightModeColors.accentOrange
                    : LightModeColors.lightOnSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Text(
              report.studentName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Average
          Text(
            '${report.averageMarks.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: gradeColor,
            ),
          ),
          const SizedBox(width: 6),
          // Grade badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              report.grade,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: gradeColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Promotion
          Icon(
            report.isPassing ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: report.isPassing ? LightModeColors.accentGreen : LightModeColors.lightError,
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // POSITIONS TAB (per-subject positions from computed results)
  // =======================================================================

  Widget _buildPositionsView() {
    final results = _computedResults;
    if (results == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.leaderboard_outlined, size: 48, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.35)),
              const SizedBox(height: 12),
              const Text(
                'No computed results yet. Tap "Results" to generate positions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: LightModeColors.lightOnSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(16),
          color: LightModeColors.lightPrimary.withOpacity(0.05),
          child: Row(
            children: [
              _StatBox(
                label: 'Highest',
                value: results.summary.highestScore.toStringAsFixed(1),
                color: LightModeColors.accentGreen,
              ),
              const SizedBox(width: 8),
              _StatBox(
                label: 'Average',
                value: results.summary.averageScore.toStringAsFixed(1),
                color: LightModeColors.lightPrimary,
              ),
              const SizedBox(width: 8),
              _StatBox(
                label: 'Lowest',
                value: results.summary.lowestScore.toStringAsFixed(1),
                color: LightModeColors.accentOrange,
              ),
              const SizedBox(width: 8),
              _StatBox(
                label: 'Students',
                value: results.totalStudents.toString(),
                color: LightModeColors.accentBlue,
              ),
            ],
          ),
        ),
        // Subject label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: LightModeColors.lightSurfaceVariant,
          child: Row(
            children: [
              const Text('Subject Positions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: LightModeColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getSelectedSubjectName(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LightModeColors.accentBlue),
                ),
              ),
            ],
          ),
        ),
        // Results list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _computeResults,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: results.results.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildResultsHeader();
                return _buildResultRow(results.results[index - 1], index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: LightModeColors.lightPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
          SizedBox(width: 8),
          Expanded(child: Text('Student', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
          SizedBox(width: 4),
          SizedBox(width: 34, child: Text('CA', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
          SizedBox(width: 4),
          SizedBox(width: 34, child: Text('Exam', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
          SizedBox(width: 4),
          SizedBox(width: 36, child: Text('Final', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
          SizedBox(width: 8),
          SizedBox(width: 28, child: Text('Pos', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildResultRow(StudentResult result, int index) {
    final isTop3 = result.position <= 3;
    final gradeColor = _getGradeColor(result.grade);

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: isTop3 ? LightModeColors.accentGreen.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isTop3
            ? Border.all(color: LightModeColors.accentGreen.withOpacity(0.2), width: 1)
            : Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // Position
            SizedBox(
              width: 28,
              child: isTop3
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: {
                          1: LightModeColors.accentOrange,
                          2: LightModeColors.lightOnSurfaceVariant,
                          3: LightModeColors.accentGreen,
                        }[result.position]?.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${result.position}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: {
                              1: LightModeColors.accentOrange,
                              2: LightModeColors.lightOnSurfaceVariant,
                              3: LightModeColors.accentGreen,
                            }[result.position],
                          ),
                        ),
                      ),
                    )
                  : Text(
                      '${result.position}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: LightModeColors.lightOnSurfaceVariant),
                    ),
            ),
            const SizedBox(width: 8),
            // Name + Grade pill
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      result.studentName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _GradePill(grade: result.grade, remark: result.remark),
                ],
              ),
            ),
            // CA
            SizedBox(
              width: 34,
              child: Text(
                result.caScore.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Exam
            SizedBox(
              width: 34,
              child: Text(
                result.examScore.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.accentOrange,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Final
            SizedBox(
              width: 36,
              child: Text(
                result.finalScore.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Position badge
            SizedBox(
              width: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isTop3
                      ? LightModeColors.accentGreen.withOpacity(0.1)
                      : LightModeColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${result.position}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isTop3 ? LightModeColors.accentGreen : LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // HELPERS
  // =======================================================================

  String _getSelectedSubjectName() {
    if (_selectedSubjectId == null) return 'Subject';
    final subject = (_entryData?.subjects ?? []).firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => SubjectInfo(id: 0, name: 'Subject'),
    );
    return subject.name;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A': return LightModeColors.accentGreen;
      case 'B+':
      case 'B': return LightModeColors.accentBlue;
      case 'C+':
      case 'C': return LightModeColors.accentOrange;
      case 'D': return LightModeColors.lightError;
      case 'F': return LightModeColors.lightError;
      default: return LightModeColors.lightOnSurface;
    }
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A': return LightModeColors.accentGreen;
      case 'B': return LightModeColors.accentBlue;
      case 'C': return LightModeColors.accentOrange;
      case 'D': return LightModeColors.lightError;
      case 'F': return LightModeColors.lightError;
      default: return LightModeColors.lightOnSurfaceVariant;
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: LightModeColors.lightOnSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 1).toUpperCase();
  }
}

// =======================================================================
// SUB-WIDGETS
// =======================================================================

class _GradePill extends StatelessWidget {
  final String grade;
  final String remark;

  const _GradePill({required this.grade, required this.remark});

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _gradeColor() {
    switch (grade) {
      case 'A': return LightModeColors.accentGreen;
      case 'B+':
      case 'B': return LightModeColors.accentBlue;
      case 'C+':
      case 'C': return LightModeColors.accentOrange;
      case 'D': return LightModeColors.lightError;
      default: return Colors.red;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: LightModeColors.lightBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 14, color: LightModeColors.lightOnSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant)),
            ],
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: LightModeColors.lightOnSurface),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? LightModeColors.lightPrimary
              : LightModeColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : LightModeColors.lightOnSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : LightModeColors.lightOnSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
