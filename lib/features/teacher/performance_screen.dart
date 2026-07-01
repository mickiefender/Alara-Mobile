import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:alara/services/performance_service.dart';
import 'package:alara/theme.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceService _service = PerformanceService();
  TeacherPerformanceData? _data;
  bool _isLoading = true;
  String? _error;
  int? _selectedClassId;
  List<StudentPerformance> _filteredStudents = [];
  ClassPerformanceAnalytics? _selectedClassAnalytics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _service.getTeacherPerformance();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
          // Auto-select first class if available
          if (data.classes.isNotEmpty && _selectedClassId == null) {
            _selectedClassId = data.classes.first.classId;
          }
          _applyFilter();
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

  void _applyFilter() {
    if (_data == null) return;
    if (_selectedClassId == null) {
      _filteredStudents = _data!.students;
      _selectedClassAnalytics = null;
    } else {
      _filteredStudents = _data!.students
          .where((s) => s.classId == _selectedClassId)
          .toList();
      _selectedClassAnalytics = _data!.classes
          .where((c) => c.classId == _selectedClassId)
          .firstOrNull;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Student Performance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          if (_data != null && _data!.classes.length > 1)
            _buildClassFilter(),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: LightModeColors.lightPrimary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildClassFilter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: LightModeColors.lightPrimaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedClassId,
              hint: const Text('All Classes', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Classes', style: TextStyle(fontSize: 13))),
                ..._data!.classes.map((c) => DropdownMenuItem(
                  value: c.classId,
                  child: Text(c.className ?? 'Class', style: const TextStyle(fontSize: 13)),
                )),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedClassId = val;
                  _applyFilter();
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_data == null || (_data!.students.isEmpty && _data!.classes.isEmpty)) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Overall stats cards
        SliverToBoxAdapter(child: _buildOverallStatsCards()),
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        // Performance distribution chart
        SliverToBoxAdapter(child: _buildPerformanceChart()),
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        // Class stats
        if (_selectedClassAnalytics != null) ...[
          SliverToBoxAdapter(child: _buildClassAnalyticsCard()),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
        ],
        // Student list header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Students (${_filteredStudents.length})',
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightOnSurface,
                  ),
                ),
                if (_data!.overallStats != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _data!.overallStats!.studentsAtRisk > 0
                          ? LightModeColors.lightError.withOpacity(0.1)
                          : LightModeColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_data!.overallStats!.studentsAtRisk} at risk',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _data!.overallStats!.studentsAtRisk > 0
                            ? LightModeColors.lightError
                            : LightModeColors.accentGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 12)),
        // Student list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final student = _filteredStudents[index];
                final rank = index + 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _filteredStudents.length - 1 ? 10 : 20),
                  child: _buildStudentCard(student, rank),
                );
              },
              childCount: _filteredStudents.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatsCards() {
    final stats = _data!.overallStats;
    if (stats == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.people_rounded,
                label: 'Students',
                value: '${stats.totalStudents}',
                color: LightModeColors.accentBlue,
                bgColor: LightModeColors.accentBlue.withOpacity(0.1),
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.school_rounded,
                label: 'Classes',
                value: '${stats.totalClasses}',
                color: LightModeColors.accentGreen,
                bgColor: LightModeColors.accentGreen.withOpacity(0.1),
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.emoji_events_rounded,
                label: 'Avg Score',
                value: '${stats.averagePerformanceScore.toStringAsFixed(0)}%',
                color: LightModeColors.accentOrange,
                bgColor: LightModeColors.accentOrange.withOpacity(0.1),
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.error_outline_rounded,
                label: 'At Risk',
                value: '${stats.studentsAtRisk}',
                color: stats.studentsAtRisk > 0 ? LightModeColors.lightError : LightModeColors.accentGreen,
                bgColor: stats.studentsAtRisk > 0
                    ? LightModeColors.lightError.withOpacity(0.1)
                    : LightModeColors.accentGreen.withOpacity(0.1),
              )),
            ],
          ),
          const SizedBox(height: 16),
          // Secondary metrics row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricRow(
                    icon: Icons.check_circle_rounded,
                    label: 'Attendance',
                    value: '${stats.averageAttendancePercentage.toStringAsFixed(1)}%',
                    color: LightModeColors.accentGreen,
                  ),
                ),
                Container(width: 1, height: 32, color: LightModeColors.lightOutline),
                Expanded(
                  child: _MetricRow(
                    icon: Icons.quiz_rounded,
                    label: 'Exam Avg',
                    value: '${stats.averageExamScore.toStringAsFixed(1)}%',
                    color: LightModeColors.accentBlue,
                  ),
                ),
                Container(width: 1, height: 32, color: LightModeColors.lightOutline),
                Expanded(
                  child: _MetricRow(
                    icon: Icons.star_rounded,
                    label: 'Top Student',
                    value: stats.topPerformer ?? 'N/A',
                    color: LightModeColors.accentOrange,
                    smallText: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (_filteredStudents.isEmpty && (_data?.classes.isEmpty ?? true)) return const SizedBox.shrink();

    // Build distribution buckets
    final buckets = <int, int>{};
    for (int i = 0; i <= 100; i += 10) {
      buckets[i] = 0;
    }

    if (_filteredStudents.isNotEmpty) {
      for (final student in _filteredStudents) {
        final score = student.performanceScore.round();
        final bucket = (score ~/ 10) * 10;
        buckets[bucket] = (buckets[bucket] ?? 0) + 1;
      }
    } else {
      final classSource = _selectedClassId == null
          ? _data!.classes
          : _data!.classes.where((c) => c.classId == _selectedClassId).toList();

      for (final cls in classSource) {
        final score = cls.averageExamScore.round();
        final bucket = (score ~/ 10) * 10;
        buckets[bucket] = (buckets[bucket] ?? 0) + (cls.totalStudents > 0 ? cls.totalStudents : 1);
      }
    }

    final sortedBuckets = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final maxCount = sortedBuckets.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Distribution',
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightOnSurface,
                  ),
                ),
                Text(
                  _filteredStudents.isNotEmpty
                      ? '${_filteredStudents.length} students'
                      : '${_data!.classes.length} classes',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount > 0 ? maxCount * 1.3 : 10,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => LightModeColors.lightOnSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = sortedBuckets[group.x.toInt()].key;
                        final endLabel = label + 10;
                        return BarTooltipItem(
                          '$label% - $endLabel%\n${rod.toY.round()} students',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= sortedBuckets.length) return const SizedBox();
                          final label = sortedBuckets[idx].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$label',
                              style: const TextStyle(fontSize: 9, color: LightModeColors.lightOnSurfaceVariant),
                            ),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10, color: LightModeColors.lightOnSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxCount > 0 ? (maxCount / 3).ceilToDouble().clamp(1, double.infinity) : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: LightModeColors.lightOutline.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedBuckets.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final bucket = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: bucket.value.toDouble(),
                          color: _getBarColor(bucket.key),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBarColor(int bucketStart) {
    if (bucketStart >= 80) return LightModeColors.accentGreen;
    if (bucketStart >= 60) return LightModeColors.accentBlue;
    if (bucketStart >= 40) return LightModeColors.accentOrange;
    return LightModeColors.lightError;
  }

  Widget _buildClassAnalyticsCard() {
    final cls = _selectedClassAnalytics!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.class_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls.className ?? 'Class',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cls.totalStudents} students',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                _ClassStatItem(
                  label: 'Avg Attendance',
                  value: '${cls.overallAttendancePercentage.toStringAsFixed(1)}%',
                  color: LightModeColors.accentGreen,
                  icon: Icons.how_to_reg_rounded,
                ),
                const SizedBox(width: 8),
                _ClassStatItem(
                  label: 'Avg Exam Score',
                  value: '${cls.averageExamScore.toStringAsFixed(1)}%',
                  color: LightModeColors.accentBlue,
                  icon: Icons.quiz_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Grade distribution chips
            const Text(
              'Grade Distribution',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: LightModeColors.lightOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
              Row(
                children: ['A', 'B', 'C', 'D', 'E', 'F'].map((grade) {
                final count = cls.gradeDistribution[grade] ?? 0;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: _gradeColor(grade).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _gradeColor(grade),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        grade,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _gradeColor(grade),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentPerformance student, int rank) {
    final performanceColor = student.performanceScore >= 80
        ? LightModeColors.accentGreen
        : student.performanceScore >= 60
            ? LightModeColors.accentBlue
            : student.performanceScore >= 40
                ? LightModeColors.accentOrange
                : LightModeColors.lightError;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showStudentDetail(student),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? LightModeColors.accentOrange.withOpacity(0.15)
                      : LightModeColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? LightModeColors.accentOrange : LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Student avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    student.studentName.isNotEmpty
                        ? student.studentName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: LightModeColors.lightPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Student info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          student.className ?? '',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        if (student.className != null && student.grade != 'N/A') ...[
                          Container(width: 1, height: 10, color: LightModeColors.lightOutline, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          Text(
                            'Grade ${student.grade}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _gradeColor(student.grade),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Performance bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: student.performanceScore / 100,
                        backgroundColor: LightModeColors.lightSurfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(performanceColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Score
              Column(
                children: [
                  Text(
                    '${student.performanceScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: performanceColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${student.examPerformance.averageScore.toStringAsFixed(0)}% exam',
                    style: const TextStyle(
                      fontSize: 10,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentDetail(StudentPerformance student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentDetailSheet(student: student),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Could not load performance data',
              style: context.textStyles.titleMedium?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text('Pull down to retry', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No performance data yet',
              style: context.textStyles.titleMedium?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Data will appear once students have attendance records and exam scores',
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A': return LightModeColors.accentGreen;
      case 'B': return LightModeColors.accentBlue;
      case 'C': return LightModeColors.accentOrange;
      case 'D': return LightModeColors.accentOrange;
      case 'E': return LightModeColors.lightError;
      case 'F': return LightModeColors.lightError;
      default: return LightModeColors.lightOnSurfaceVariant;
    }
  }
}

// ====== Stat Card Widget ======
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
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
            style: const TextStyle(
              fontSize: 9,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Metric Row Widget ======
class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool smallText;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: LightModeColors.lightOnSurfaceVariant)),
            Text(
              value,
              style: TextStyle(
                fontSize: smallText ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: LightModeColors.lightOnSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

// ====== Class Stat Item ======
class _ClassStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ClassStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: LightModeColors.lightOnSurfaceVariant)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
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

// ====== Student Detail Bottom Sheet ======
class _StudentDetailSheet extends StatelessWidget {
  final StudentPerformance student;

  const _StudentDetailSheet({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: LightModeColors.lightOutline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      children: [
                        // Avatar and name
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              student.studentName.isNotEmpty
                                  ? student.studentName.substring(0, 2).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          student.studentName,
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: LightModeColors.lightOnSurface,
                          ),
                        ),
                        if (student.className != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            student.className!,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Overall performance ring
                        _buildPerformanceRing(context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Stats grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(child: _DetailStatCard(
                          icon: Icons.how_to_reg_rounded,
                          label: 'Attendance',
                          value: '${student.attendance.percentage.toStringAsFixed(1)}%',
                          subValue: '${student.attendance.present}/${student.attendance.totalDays} days',
                          color: LightModeColors.accentGreen,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _DetailStatCard(
                          icon: Icons.quiz_rounded,
                          label: 'Exam Avg',
                          value: '${student.examPerformance.averageScore.toStringAsFixed(1)}%',
                          subValue: '${student.examPerformance.totalExams} exams',
                          color: LightModeColors.accentBlue,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _DetailStatCard(
                          icon: Icons.emoji_events_rounded,
                          label: 'Highest',
                          value: '${student.examPerformance.highestScore.toStringAsFixed(0)}%',
                          subValue: 'Best exam',
                          color: LightModeColors.accentOrange,
                        )),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
                // Subject breakdown
                if (student.subjectPerformances.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subject Performance',
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.lightOnSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...student.subjectPerformances.map((sp) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightBackground,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sp.subjectName,
                                          style: context.textStyles.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: sp.averageScore / 100,
                                            backgroundColor: LightModeColors.lightOutline,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              sp.averageScore >= 70 ? LightModeColors.accentGreen
                                                  : sp.averageScore >= 50 ? LightModeColors.accentOrange
                                                  : LightModeColors.lightError,
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Best: ${sp.bestScore.toStringAsFixed(0)}% · Latest: ${sp.latestScore.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: LightModeColors.lightOnSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${sp.averageScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: sp.averageScore >= 70 ? LightModeColors.accentGreen
                                          : sp.averageScore >= 50 ? LightModeColors.accentOrange
                                          : LightModeColors.lightError,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                // Attendance breakdown
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LightModeColors.lightBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Breakdown',
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.lightOnSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _AttStat(color: LightModeColors.accentGreen, label: 'Present', value: '${student.attendance.present}'),
                              const SizedBox(width: 8),
                              _AttStat(color: LightModeColors.accentOrange, label: 'Late', value: '${student.attendance.late}'),
                              const SizedBox(width: 8),
                              _AttStat(color: LightModeColors.lightError, label: 'Absent', value: '${student.attendance.absent}'),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildPerformanceRing(BuildContext context) {
    final score = student.performanceScore;
    final grade = student.grade;
    final color = score >= 80
        ? LightModeColors.accentGreen
        : score >= 60
            ? LightModeColors.accentBlue
            : score >= 40
                ? LightModeColors.accentOrange
                : LightModeColors.lightError;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (grade != 'N/A')
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subValue;
  final Color color;

  const _DetailStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
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
            style: const TextStyle(
              fontSize: 10,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
          Text(
            subValue,
            style: const TextStyle(
              fontSize: 9,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttStat extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _AttStat({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
