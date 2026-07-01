import 'package:flutter/material.dart';
import 'package:alara/services/terminal_report_service.dart';
import 'package:alara/services/grading_service.dart';
import 'package:alara/theme.dart';

class TerminalReportResultsScreen extends StatefulWidget {
  const TerminalReportResultsScreen({super.key});

  @override
  State<TerminalReportResultsScreen> createState() => _TerminalReportResultsScreenState();
}

class _TerminalReportResultsScreenState extends State<TerminalReportResultsScreen> {
  final TerminalReportService _service = TerminalReportService();

  // Selection state
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sessions = [];
  int? _selectedClassId;
  int? _selectedSessionId;

  // Data
  List<StudentTerminalReport> _reports = [];
  ClassReportsSummary? _summary;
  GradingSystemInfo? _gradingSystem;
  List<AssessmentTypeInfo> _continuousAssessments = [];
  List<AssessmentTypeInfo> _examinations = [];
  bool _isLoading = false;
  bool _isComputing = false;
  String? _error;
  String? _successMessage;

  // Expanded student detail
  int? _expandedStudentId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadSessions();
  }

  Future<void> _loadClasses() async {
    try {
      final service = GradingService();
      final classes = await service.getTeacherClasses();
      if (mounted) {
        setState(() {
          _classes = classes;
          if (classes.isNotEmpty && _selectedClassId == null) {
            _selectedClassId = int.tryParse(classes.first['id'].toString());
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    try {
      final service = GradingService();
      final sessions = await service.getAcademicSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          final current = sessions.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['is_current'] == true,
            orElse: () => sessions.isNotEmpty ? sessions.first : null,
          );
          if (current != null) {
            _selectedSessionId = int.tryParse(current['id'].toString());
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReports() async {
    if (_selectedClassId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _reports = [];
      _summary = null;
    });

    try {
      final data = await _service.getClassReports(
        classId: _selectedClassId!,
        sessionId: _selectedSessionId,
      );
      if (mounted) {
        setState(() {
          _reports = data.reports;
          _summary = data.summary;
          _gradingSystem = data.gradingSystem;
          _continuousAssessments = data.continuousAssessments;
          _examinations = data.examinations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _computeReports() async {
    if (_selectedClassId == null || _selectedSessionId == null) {
      _showMessage('Select both class and session', isError: true);
      return;
    }

    setState(() => _isComputing = true);

    try {
      final result = await _service.computeClassReports(
        classId: _selectedClassId!,
        sessionId: _selectedSessionId!,
      );
      if (mounted) {
        final generated = result['reports_generated'] ?? 0;
        _showMessage('$generated reports generated', isError: false);
        await _loadReports();
      }
    } catch (e) {
      if (mounted) _showMessage('Failed to compute: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isComputing = false);
    }
  }

  void _showMessage(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? LightModeColors.lightError : LightModeColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Terminal Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          if (_reports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadReports,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSelectionBar(),
          if (_summary != null) _buildSummaryBanner(),
          if (_gradingSystem != null || _continuousAssessments.isNotEmpty || _examinations.isNotEmpty)
            _buildGradingAndExamTypesPanel(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _DropdownField(
              label: 'Class',
              value: _selectedClassId?.toString(),
              items: _classes.map((c) {
                return DropdownMenuItem(
                  value: c['id'].toString(),
                  child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedClassId = val != null ? int.tryParse(val) : null;
                  _reports = [];
                  _summary = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
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
                  _reports = [];
                  _summary = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadReports,
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Load', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isComputing ? null : _computeReports,
              icon: _isComputing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_graph_rounded, size: 16),
              label: Text(_isComputing ? '...' : 'Compute', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final s = _summary!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LightModeColors.lightPrimary.withOpacity(0.08),
            LightModeColors.lightSecondary.withOpacity(0.08),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: LightModeColors.lightOutline.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  label: 'Avg Score',
                  value: '${s.averageScore.toStringAsFixed(1)}%',
                  color: LightModeColors.lightPrimary,
                  icon: Icons.analytics_rounded,
                ),
              ),
              Expanded(
                child: _SummaryChip(
                  label: 'Best Student',
                  value: s.bestStudentName ?? 'N/A',
                  color: LightModeColors.accentOrange,
                  icon: Icons.emoji_events_rounded,
                  smallText: true,
                ),
              ),
              Expanded(
                child: _SummaryChip(
                  label: 'Best Subject',
                  value: s.bestSubjectName ?? 'N/A',
                  color: LightModeColors.accentGreen,
                  icon: Icons.star_rounded,
                  smallText: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(label: 'Promoted', value: '${s.studentsPromoted}', color: LightModeColors.accentGreen),
              const SizedBox(width: 8),
              _MiniStat(label: 'Repeated', value: '${s.studentsRepeated}', color: s.studentsRepeated > 0 ? LightModeColors.lightError : LightModeColors.accentGreen),
              const SizedBox(width: 8),
              _MiniStat(label: 'Total Students', value: '${s.totalStudents}', color: LightModeColors.accentBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_reports.isEmpty && _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_rounded, size: 56, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.35)),
              const SizedBox(height: 12),
              Text(
                'Select a class and session, then tap Load.\nTap Compute to generate new reports.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: LightModeColors.lightOnSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          final isExpanded = _expandedStudentId == report.studentId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildReportCard(report, isExpanded),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(StudentTerminalReport report, bool isExpanded) {
    final gradeColor = _gradeColor(report.grade);
    final promotionColor = report.isPassing ? LightModeColors.accentGreen : LightModeColors.lightError;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _expandedStudentId = isExpanded ? null : report.studentId;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: report.isPassing ? LightModeColors.accentGreen.withOpacity(0.2) : LightModeColors.lightError.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    // Position badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: report.position != null && report.position! <= 3
                            ? LightModeColors.accentOrange.withOpacity(0.15)
                            : LightModeColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          report.positionText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: report.position != null && report.position! <= 3
                                ? LightModeColors.accentOrange
                                : LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          report.studentName.isNotEmpty
                              ? report.studentName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.studentName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: gradeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  report.grade,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: gradeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${report.averageMarks.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: gradeColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Promotion status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: promotionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        report.promotionText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: promotionColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: LightModeColors.lightOnSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
              // Expanded subject scores
              if (isExpanded) _buildExpandedContent(report),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(StudentTerminalReport report) {
    return Container(
      decoration: BoxDecoration(
        color: LightModeColors.lightBackground,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats row
          Row(
            children: [
              _QuickStat(
                icon: Icons.trending_up_rounded,
                label: 'Best Subject',
                value: report.bestSubjectName.isNotEmpty
                    ? '${report.bestSubjectName} (${report.bestSubjectScore.toStringAsFixed(0)}%)'
                    : 'N/A',
                color: LightModeColors.accentGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _QuickStat(
                icon: Icons.how_to_reg_rounded,
                label: 'Attendance',
                value: report.attendanceText,
                color: LightModeColors.accentBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Subject scores table header
          const Text(
            'Subject Performance',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LightModeColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                SizedBox(width: 8),
                SizedBox(width: 30, child: Text('Score', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                SizedBox(width: 8),
                SizedBox(width: 30, child: Text('Grade', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                SizedBox(width: 8),
                SizedBox(width: 45, child: Text('Position', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...report.subjectScores.map((ss) => _buildSubjectRow(ss)),

          // Remarks
          if (report.formTeacherRemarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RemarkBox(label: 'Teacher Remark', text: report.formTeacherRemarks),
          ],
          if (report.principalRemarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            _RemarkBox(label: 'Principal Remark', text: report.principalRemarks),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectRow(SubjectScoreResult ss) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(ss.subjectName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '${ss.percentage.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ss.grade == 'A' || ss.grade == 'B'
                    ? LightModeColors.accentGreen
                    : ss.grade == 'C'
                        ? LightModeColors.accentOrange
                        : LightModeColors.lightError,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _gradeColor(ss.grade).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ss.grade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _gradeColor(ss.grade),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Text(
              ss.subjectPosition != null
                  ? '${ss.subjectPosition}/${ss.subjectTotalStudents}'
                  : 'N/A',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: LightModeColors.lightOnSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingAndExamTypesPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grading System & Exam Types',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_gradingSystem != null) ...[
            Text(
              _gradingSystem!.name + (_gradingSystem!.isDefault ? ' (Default)' : ''),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LightModeColors.lightOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _gradingSystem!.entries.map((e) {
                final color = e.promotionEligible ? LightModeColors.accentGreen : LightModeColors.lightError;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${e.gradeLetter}: ${e.minPercentage.toStringAsFixed(0)}-${e.maxPercentage.toStringAsFixed(0)}% (${e.promotionEligible ? 'Promote' : 'Repeat'})',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (_continuousAssessments.isNotEmpty || _examinations.isNotEmpty) ...[
            const Text(
              'Exam Types Created by School Admin',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._continuousAssessments.map((a) => _assessmentChip(a, LightModeColors.accentBlue)),
                ..._examinations.map((a) => _assessmentChip(a, LightModeColors.accentOrange)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _assessmentChip(AssessmentTypeInfo a, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        a.title,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
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
}

// ====== SUB-WIDGETS ======

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: LightModeColors.lightBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: const TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant)),
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

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool smallText;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: LightModeColors.lightOnSurfaceVariant)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: smallText ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: LightModeColors.lightOnSurfaceVariant)),
              Text(
                value,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemarkBox extends StatelessWidget {
  final String label;
  final String text;

  const _RemarkBox({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: LightModeColors.lightOutline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LightModeColors.lightOnSurfaceVariant)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
