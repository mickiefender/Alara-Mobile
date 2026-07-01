import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/theme.dart';
import 'package:alara/services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _service = AttendanceService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSection;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String _searchQuery = '';

  // For list/grid view toggle
  bool _isGridView = false;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<StudentAttendanceRecord> _students = [];
  List<StudentAttendanceRecord> _filteredStudents = [];

  bool _isLoadingClasses = true;
  bool _isLoadingSubjects = false;
  bool _isLoadingStudents = false;
  bool _isSubmitting = false;
  bool _hasLoadedExisting = false;

  // Attendance summary
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _excusedCount = 0;

  bool _showQuickActions = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch subjects for the currently selected class from the backend.
  Future<void> _loadSubjectsForClass() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoadingSubjects = true);

    final subjects = await _service.getTeacherSubjectsForClass(_selectedClassId!);

    if (mounted) {
      setState(() {
        _subjects = subjects;
        _isLoadingSubjects = false;
        // Auto-select the first subject
        if (subjects.isNotEmpty) {
          _selectedSubjectId = subjects.first['id'].toString();
          _selectedSubjectName = subjects.first['name']?.toString();
        } else {
          _selectedSubjectId = null;
          _selectedSubjectName = null;
        }
      });
    }
  }

  void _selectClass(Map<String, dynamic> classData) {
    _selectedClassId = classData['id'].toString();
    _selectedClassName = classData['name']?.toString();
    _selectedSection = classData['section']?.toString();

    // Reset subject selection and fetch from backend
    _selectedSubjectId = null;
    _selectedSubjectName = null;
    _subjects = [];

    _loadSubjectsForClass();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);
    final classes = await _service.getTeacherClasses();
    if (mounted) {
      setState(() {
        _classes = classes;
        _isLoadingClasses = false;
        if (classes.isNotEmpty) {
          _selectClass(classes[0]);
          _loadStudents();
        }
      });
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;
    setState(() {
      _isLoadingStudents = true;
      _hasLoadedExisting = false;
    });

    final students = await _service.getStudents(
      _selectedClassId!,
      section: _selectedSection,
    );

    final existing = _selectedSubjectId != null
        ? await _service.getExistingAttendance(_selectedClassId!, _selectedDate, subjectId: _selectedSubjectId)
        : <String, String>{};

    if (existing.isNotEmpty) {
      for (final student in students) {
        final key = student.id;
        if (existing.containsKey(key)) {
          student.status = existing[key]!;
        }
      }
    }

    if (mounted) {
      setState(() {
        _students = students;
        _hasLoadedExisting = existing.isNotEmpty;
        _applyFilter();
        _isLoadingStudents = false;
      });
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredStudents = List.from(_students);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredStudents = _students.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.rollNumber?.toLowerCase().contains(q) ?? false) ||
        (s.studentId?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    _recalculateStats();
  }

  void _recalculateStats() {
    _presentCount = _students.where((s) => s.status == 'present').length;
    _absentCount = _students.where((s) => s.status == 'absent').length;
    _lateCount = _students.where((s) => s.status == 'late').length;
    _excusedCount = _students.where((s) => s.status == 'excused').length;
  }

  void _setStatusForAll(String status) {
    setState(() {
      for (final student in _students) {
        student.status = status;
      }
      _recalculateStats();
      _showQuickActions = false;
    });
  }

  void _setStudentStatus(String studentId, String status) {
    setState(() {
      final idx = _students.indexWhere((s) => s.id == studentId);
      if (idx != -1) {
        _students[idx].status = status;
      }
      _recalculateStats();
    });
  }

  Future<void> _submitAttendance() async {
    if (_selectedClassId == null || _isSubmitting) return;
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please select a subject first'),
            ],
          ),
          backgroundColor: LightModeColors.accentOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final records = _students.map((s) => {
      'student_id': s.id,
      'status': s.status,
    }).toList();

    final success = await _service.submitAttendance(
      classId: _selectedClassId!,
      date: _selectedDate,
      subjectId: _selectedSubjectId!,
      records: records,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  success
                      ? 'Attendance saved for ${_students.length} students'
                      : 'Failed to submit attendance',
                ),
              ),
            ],
          ),
          backgroundColor: success ? LightModeColors.accentGreen : LightModeColors.lightError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );

      if (success) {
        _hasLoadedExisting = true;
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: LightModeColors.lightPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null && date != _selectedDate) {
      setState(() => _selectedDate = date);
      if (_selectedClassId != null) {
        _loadStudents();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance', style: TextStyle(fontSize: 20)),
            if (_selectedClassName != null)
              Text(
                _selectedClassName!,
                style: TextStyle(
                  fontSize: 13,
                  color: LightModeColors.lightOnSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          // View toggle
          if (_students.isNotEmpty && !_isLoadingStudents)
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView ? 'List view' : 'Grid view',
            ),
          // Submit button
          if (_students.isNotEmpty && !_isLoadingStudents)
            TextButton.icon(
              onPressed: _isSubmitting ? null : _submitAttendance,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(_isSubmitting ? 'Saving...' : 'Save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: LightModeColors.accentGreen,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & search bar
          _buildFilterBar(),
          // Summary & quick actions
          if (_students.isNotEmpty && !_isLoadingStudents) ...[
            _buildSummarySection(),
            _buildQuickActionsSection(),
          ],
          // Student list/grid
          Expanded(
            child: _isLoadingClasses
                ? const Center(child: CircularProgressIndicator())
                : _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : _classes.isEmpty
                        ? _buildEmptyState('No classes assigned yet', Icons.school_outlined)
                        : _students.isEmpty
                            ? _buildEmptyState('No students in this class', Icons.people_outline)
                            : _filteredStudents.isEmpty
                                ? _buildEmptyState('No results for "$_searchQuery"', Icons.search_off)
                                : _isGridView
                                    ? _buildStudentGrid()
                                    : _buildStudentList(),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // FILTER BAR
  // ================================================================

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
          // Class picker + Date picker
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _showClassPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school_rounded, size: 18, color: LightModeColors.lightPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedClassName ?? 'Select class',
                            style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: LightModeColors.lightOnSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: LightModeColors.lightPrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('dd MMM').format(_selectedDate),
                            style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subject picker
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _subjects.isNotEmpty ? _showSubjectPicker : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedSubjectId != null
                          ? Border.all(color: LightModeColors.lightPrimary.withOpacity(0.2))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isLoadingSubjects
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.book_rounded, size: 16, color: LightModeColors.lightPrimary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subject',
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: LightModeColors.lightOnSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _isLoadingSubjects
                                    ? 'Loading...'
                                    : (_selectedSubjectName ?? 'Select subject'),
                                style: context.textStyles.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _selectedSubjectName != null
                                      ? LightModeColors.lightOnSurface
                                      : LightModeColors.lightOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_subjects.isNotEmpty)
                          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: LightModeColors.lightOnSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search
          Container(
            decoration: BoxDecoration(
              color: LightModeColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _searchQuery = v;
                _applyFilter();
              },
              style: context.textStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search by name or roll no...',
                hintStyle: TextStyle(color: LightModeColors.lightOnSurfaceVariant),
                prefixIcon: Icon(Icons.search_rounded, color: LightModeColors.lightOnSurfaceVariant, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _applyFilter();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SUMMARY SECTION
  // ================================================================

  Widget _buildSummarySection() {
    final total = _students.length;
    final presentPercent = total > 0 ? (_presentCount / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      color: Colors.white,
      child: Column(
        children: [
          // Date + info row
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: LightModeColors.lightOnSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _hasLoadedExisting
                      ? LightModeColors.accentBlue.withOpacity(0.1)
                      : LightModeColors.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _hasLoadedExisting ? 'Previously saved' : 'New entry',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _hasLoadedExisting ? LightModeColors.accentBlue : LightModeColors.accentOrange,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$total students',
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              // Rate indicator
              _buildRateIndicator(presentPercent),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      _buildStatBar('P', _presentCount, total, LightModeColors.accentGreen),
                      const SizedBox(width: 4),
                      _buildStatBar('A', _absentCount, total, LightModeColors.lightError),
                      const SizedBox(width: 4),
                      _buildStatBar('L', _lateCount, total, LightModeColors.accentOrange),
                      const SizedBox(width: 4),
                      _buildStatBar('E', _excusedCount, total, LightModeColors.accentBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quick actions toggle
              InkWell(
                onTap: () => setState(() => _showQuickActions = !_showQuickActions),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _showQuickActions
                        ? LightModeColors.lightPrimary.withOpacity(0.1)
                        : LightModeColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: _showQuickActions
                        ? Border.all(color: LightModeColors.lightPrimary.withOpacity(0.3))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: _showQuickActions
                            ? LightModeColors.lightPrimary
                            : LightModeColors.lightOnSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Quick',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showQuickActions
                              ? LightModeColors.lightPrimary
                              : LightModeColors.lightOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateIndicator(int percent) {
    final color = _getRateColor(percent);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'Rate',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    final height = 20.0 + (fraction * 20.0); // min 20, max 40

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: height.clamp(4, 40),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2 + (fraction * 0.6)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // QUICK ACTIONS
  // ================================================================

  Widget _buildQuickActionsSection() {
    if (!_showQuickActions) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            'Mark all as:',
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQuickActionChip('Present', LightModeColors.accentGreen, Icons.check_circle_rounded, 'present'),
              const SizedBox(width: 8),
              _buildQuickActionChip('Absent', LightModeColors.lightError, Icons.cancel_rounded, 'absent'),
              const SizedBox(width: 8),
              _buildQuickActionChip('Late', LightModeColors.accentOrange, Icons.schedule_rounded, 'late'),
              const SizedBox(width: 8),
              _buildQuickActionChip('Excused', LightModeColors.accentBlue, Icons.medical_services_rounded, 'excused'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label, Color color, IconData icon, String status) {
    return Expanded(
      child: InkWell(
        onTap: () => _setStatusForAll(status),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // STUDENT LIST VIEW
  // ================================================================

  Widget _buildStudentList() {
    return RefreshIndicator(
      onRefresh: _loadStudents,
      color: LightModeColors.lightPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          return _buildStudentListCard(student, index);
        },
      ),
    );
  }

  Widget _buildStudentListCard(StudentAttendanceRecord student, int index) {
    final status = student.status;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusLabel = _getStatusLabel(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showStatusPicker(student),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: LightModeColors.lightPrimaryContainer,
                    child: Text(
                      student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Student info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: context.textStyles.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: LightModeColors.lightOnSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (student.rollNumber != null) ...[
                              Icon(Icons.tag_rounded, size: 12, color: LightModeColors.lightOnSurfaceVariant),
                              const SizedBox(width: 3),
                              Text(
                                student.rollNumber!,
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: LightModeColors.lightOnSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Icon(Icons.fingerprint, size: 12, color: LightModeColors.lightOnSurfaceVariant),
                            const SizedBox(width: 3),
                            Text(
                              '#${student.id.length > 6 ? student.id.substring(0, 6) : student.id}',
                              style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: LightModeColors.lightOnSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // STUDENT GRID VIEW
  // ================================================================

  Widget _buildStudentGrid() {
    return RefreshIndicator(
      onRefresh: _loadStudents,
      color: LightModeColors.lightPrimary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          return _buildStudentGridCard(student, index);
        },
      ),
    );
  }

  Widget _buildStudentGridCard(StudentAttendanceRecord student, int index) {
    final status = student.status;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusLabel = _getStatusLabel(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showStatusPicker(student),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circle avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: LightModeColors.lightPrimaryContainer,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.lightPrimary,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  student.name,
                  style: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightOnSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (student.rollNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Roll: ${student.rollNumber}',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
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
    );
  }

  // ================================================================
  // STATUS PICKER BOTTOM SHEET
  // ================================================================

  void _showStatusPicker(StudentAttendanceRecord student) {
    final statuses = [
      {'label': 'Present', 'status': 'present', 'icon': Icons.check_circle_rounded, 'color': LightModeColors.accentGreen},
      {'label': 'Absent', 'status': 'absent', 'icon': Icons.cancel_rounded, 'color': LightModeColors.lightError},
      {'label': 'Late', 'status': 'late', 'icon': Icons.schedule_rounded, 'color': LightModeColors.accentOrange},
      {'label': 'Excused', 'status': 'excused', 'icon': Icons.medical_services_rounded, 'color': LightModeColors.accentBlue},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LightModeColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Student header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: LightModeColors.lightPrimaryContainer,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.lightPrimary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (student.rollNumber != null)
                        Text(
                          'Roll Number: ${student.rollNumber}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Current status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(student.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusLabel(student.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(student.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Mark as:',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: LightModeColors.lightOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...statuses.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _setStudentStatus(student.id, s['status'] as String);
                  Navigator.of(ctx).pop();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: (s['color'] as Color).withOpacity(student.status == s['status'] ? 0.12 : 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: student.status == s['status']
                        ? Border.all(color: (s['color'] as Color), width: 2)
                        : Border.all(color: (s['color'] as Color).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (s['color'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          s['label'] as String,
                          style: context.textStyles.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: LightModeColors.lightOnSurface,
                          ),
                        ),
                      ),
                      if (student.status == s['status'])
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: (s['color'] as Color),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // CLASS PICKER BOTTOM SHEET
  // ================================================================

  void _showClassPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LightModeColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Select Class',
                  style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isLoadingClasses)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the class you want to mark attendance for',
              style: context.textStyles.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingClasses)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else
              ...List.generate(_classes.length, (i) {
                final c = _classes[i];
                final name = c['name']?.toString() ?? 'Unknown';
                final section = c['section']?.toString();
                final studentCount = c['student_count'] ?? 0;
                final isFormTutor = c['is_form_tutor'] ?? false;
                final isSelected = _selectedClassId == c['id'].toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectClass(c);
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      Navigator.of(ctx).pop();
                      _loadStudents();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? LightModeColors.lightPrimary.withOpacity(0.08)
                            : LightModeColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(color: LightModeColors.lightPrimary, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  LightModeColors.lightPrimary.withOpacity(0.85),
                                  LightModeColors.lightSecondary.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                name.substring(0, 2).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: context.textStyles.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (section != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: LightModeColors.accentBlue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Sec $section',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: LightModeColors.accentBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$studentCount students · ${_getSubjectsCount(c)} subject(s)',
                                  style: context.textStyles.bodySmall?.copyWith(
                                    color: LightModeColors.lightOnSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isFormTutor)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: LightModeColors.accentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Form Tutor',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: LightModeColors.accentGreen,
                                ),
                              ),
                            ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: LightModeColors.lightPrimary,
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showSubjectPicker() {
    if (_subjects.isEmpty) return;
    final subjects = _subjects;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LightModeColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Subject',
              style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(subjects.length, (i) {
              final subject = subjects[i];
              final subId = subject['id'].toString();
              final subName = subject['name']?.toString() ?? 'Subject ${i + 1}';
              final isSelected = _selectedSubjectId == subId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSubjectId = subId;
                      _selectedSubjectName = subName;
                    });
                    Navigator.of(ctx).pop();
                    _loadStudents();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? LightModeColors.lightPrimary.withOpacity(0.08)
                          : LightModeColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: LightModeColors.lightPrimary, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              subName.substring(0, 2).toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.lightPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          subName,
                          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (subject['code'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: LightModeColors.lightOutline.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subject['code'].toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: LightModeColors.lightOnSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: LightModeColors.lightPrimary, size: 22),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  int _getSubjectsCount(Map<String, dynamic> classData) {
    final subjects = classData['subjects_taught'] as List?;
    return subjects?.length ?? 0;
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: LightModeColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: context.textStyles.titleMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // HELPERS
  // ================================================================

  Color _getRateColor(int percent) {
    if (percent >= 90) return LightModeColors.accentGreen;
    if (percent >= 75) return LightModeColors.accentOrange;
    return LightModeColors.lightError;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return LightModeColors.accentGreen;
      case 'absent': return LightModeColors.lightError;
      case 'late': return LightModeColors.accentOrange;
      case 'excused': return LightModeColors.accentBlue;
      default: return LightModeColors.lightOnSurfaceVariant;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle_rounded;
      case 'absent': return Icons.cancel_rounded;
      case 'late': return Icons.schedule_rounded;
      case 'excused': return Icons.medical_services_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'present': return 'Present';
      case 'absent': return 'Absent';
      case 'late': return 'Late';
      case 'excused': return 'Excused';
      default: return 'Unknown';
    }
  }
}
