import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/theme.dart';
import 'package:alara/services/attendance_service.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final AttendanceService _service = AttendanceService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSection;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String _searchQuery = '';

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<StudentAttendanceRecord> _students = [];
  List<StudentAttendanceRecord> _filteredStudents = [];

  bool _isLoadingClasses = true;
  bool _isLoadingSubjects = false;
  bool _isLoadingStudents = false;
  bool _isSubmitting = false;

  // Attendance statistics
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _excusedCount = 0;

  // Quick actions: mark all as
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

  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);
    final classes = await _service.getTeacherClasses();
    if (mounted) {
      setState(() {
        _classes = classes;
        _isLoadingClasses = false;
        if (classes.isNotEmpty) {
          _selectClass(classes[0]);
        }
      });
    }
  }

  void _selectClass(Map<String, dynamic> classData) {
    _selectedClassName = classData['name']?.toString();
    _selectedSection = classData['section']?.toString();
    final newClassId = classData['id'].toString();

    _selectedClassId = newClassId;

    // Reset subject selection and fetch from backend
    _selectedSubjectId = null;
    _selectedSubjectName = null;
    _subjects = [];

    _loadSubjectsForClass();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;
    setState(() {
      _isLoadingStudents = true;
    });

    final students = await _service.getStudents(
      _selectedClassId!,
      section: _selectedSection,
    );

    // Try to load existing attendance for today/selected date
    if (_selectedSubjectId != null) {
      final existing = await _service.getExistingAttendance(
        _selectedClassId!,
        _selectedDate,
        subjectId: _selectedSubjectId,
      );
      if (existing.isNotEmpty) {
        for (final student in students) {
          final key = student.id;
          if (existing.containsKey(key)) {
            student.status = existing[key]!;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _students = students;
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
              Flexible(
                child: Text(
                  success
                      ? 'Attendance marked for ${_students.length} students'
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
        title: const Text(
          'Attendance',
          style: TextStyle(color: Colors.white),
        ),
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
        actions: [
          if (_students.isNotEmpty && !_isLoadingStudents)
            TextButton.icon(
              onPressed: _isSubmitting ? null : _submitAttendance,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: Text(
                _isSubmitting ? 'Saving...' : 'Submit',
                style: const TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
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
          // Filters bar
          _buildFilterBar(),
          // Summary bar
          if (_students.isNotEmpty && !_isLoadingStudents) _buildSummaryBar(),
          // Quick actions row
          if (_students.isNotEmpty && !_isLoadingStudents) _buildQuickActionsBar(),
          // Student list
          Expanded(
            child: _isLoadingClasses
                ? const Center(child: CircularProgressIndicator())
                : _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : _classes.isEmpty
                        ? _buildEmptyState('No classes assigned', Icons.school_outlined)
                        : _students.isEmpty
                            ? _buildEmptyState('No students found for this class', Icons.people_outline)
                            : _filteredStudents.isEmpty
                                ? _buildEmptyState('No students match "$_searchQuery"', Icons.search_off)
                                : _buildStudentList(),
          ),
        ],
      ),
    );
  }

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
          // Class picker + Date picker row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildDropdownField(
                  value: _selectedClassName ?? 'Select class',
                  items: _classes.map((c) {
                    final name = c['name']?.toString() ?? 'Unknown';
                    final section = c['section']?.toString();
                    return section != null ? '$name - $section' : name;
                  }).toList(),
                  onTap: () => _showClassPicker(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildDateField(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subject picker row
          Row(
            children: [
              Expanded(
                child: _buildSubjectChip(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search field
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
                hintText: 'Search by name, roll no...',
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

  Widget _buildSubjectChip() {
    return InkWell(
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
    );
  }

  void _showSubjectPicker() {
    if (_subjects.isEmpty) return;
    final subjects = _subjects;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.75,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
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
                Expanded(
                  child: ListView.separated(
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final subject = subjects[i];
                      final subId = subject['id'].toString();
                      final subName = subject['name']?.toString() ?? 'Subject ${i + 1}';
                      final isSelected = _selectedSubjectId == subId;

                      return InkWell(
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
                              Expanded(
                                child: Text(
                                  subName,
                                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                              const SizedBox(width: 8),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: LightModeColors.lightPrimary, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
                value,
                style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: LightModeColors.lightOnSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
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
    );
  }

  Widget _buildSummaryBar() {
    final total = _students.length;
    final presentPercent = total > 0 ? (_presentCount / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: Colors.white,
      child: Row(
        children: [
          // Attendance rate circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getRateColor(presentPercent).withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                '$presentPercent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getRateColor(presentPercent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMiniStat('P', '$_presentCount', LightModeColors.accentGreen),
                  const SizedBox(width: 14),
                  _buildMiniStat('A', '$_absentCount', LightModeColors.lightError),
                  const SizedBox(width: 14),
                  _buildMiniStat('L', '$_lateCount', LightModeColors.accentOrange),
                  const SizedBox(width: 14),
                  _buildMiniStat('E', '$_excusedCount', LightModeColors.accentBlue),
                ],
              ),
            ),
          ),
          // Quick actions toggle
          InkWell(
            onTap: () => setState(() => _showQuickActions = !_showQuickActions),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LightModeColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                color: LightModeColors.lightOnSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $count',
          style: context.textStyles.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: LightModeColors.lightOnSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsBar() {
    if (!_showQuickActions) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 16),
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
          return _buildStudentCard(student, index);
        },
      ),
    );
  }

  Widget _buildStudentCard(StudentAttendanceRecord student, int index) {
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                // Avatar / Roll number
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LightModeColors.lightPrimaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      student.rollNumber != null
                          ? student.rollNumber!.padLeft(2, '0')
                          : '${index + 1}'.padLeft(2, '0'),
                      style: context.textStyles.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightPrimary,
                        fontSize: 13,
                      ),
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
                      if (student.studentId != null)
                        Text(
                          'ID: ${student.studentId}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                // Current status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 4),
                // Toggle menu
                InkWell(
                  onTap: () => _showStatusPicker(student),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: LightModeColors.lightOnSurfaceVariant,
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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LightModeColors.lightPrimaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      student.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (student.rollNumber != null)
                        Text(
                          'Roll No: ${student.rollNumber}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(student.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusLabel(student.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(student.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Mark attendance as:',
              style: context.textStyles.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: (s['color'] as Color).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: student.status == s['status']
                        ? Border.all(color: (s['color'] as Color), width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(s['icon'] as IconData, color: s['color'] as Color, size: 24),
                      const SizedBox(width: 12),
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
                        Icon(Icons.check_circle, color: s['color'] as Color, size: 20),
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

  void _showClassPicker() {
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
              'Select Class',
              style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoadingClasses)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  LightModeColors.lightPrimary.withOpacity(0.8),
                                  LightModeColors.lightSecondary.withOpacity(0.8),
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
                                  fontSize: 15,
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
                                  '$studentCount students',
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
                              child: Icon(Icons.check_circle_rounded, color: LightModeColors.lightPrimary, size: 22),
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
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
