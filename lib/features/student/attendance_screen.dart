import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/theme.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final StudentService _service = StudentService();
  Map<String, dynamic>? _report;
  Map<String, List<Map<String, dynamic>>>? _history;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getAttendanceReport(),
        _service.getAttendanceHistory(),
      ]);
      if (mounted) {
        setState(() {
          _report = results[0] as Map<String, dynamic>;
          _history = results[1] as Map<String, List<Map<String, dynamic>>>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance Record', style: TextStyle(color: Colors.white)),
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
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _isLoading ? null : _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LightModeColors.lightPrimary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_report != null && _report!.isNotEmpty) _buildSummaryCard(),
          const SizedBox(height: 20),
          Text('Attendance History',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_history == null || _history!.isEmpty)
            _buildEmptyHistory()
          else
            ..._buildHistoryMonths(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _report!['total_days'] ?? 0;
    final present = _report!['present_days'] ?? 0;
    final absent = _report!['absent_days'] ?? 0;
    final late = _report!['late_days'] ?? 0;
    final pct = (_report!['presence_percentage'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90, height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90, height: 90,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 9,
                        backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct >= 90 ? LightModeColors.accentGreen
                              : pct >= 75 ? LightModeColors.accentOrange
                              : LightModeColors.lightError,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${pct.toStringAsFixed(0)}%',
                            style: context.textStyles.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: pct >= 90 ? LightModeColors.accentGreen
                                    : pct >= 75 ? LightModeColors.accentOrange
                                    : LightModeColors.lightError)),
                        Text('Present',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildStatRow(Icons.check_circle_rounded, 'Present', '$present', LightModeColors.accentGreen),
                    const SizedBox(height: 8),
                    _buildStatRow(Icons.cancel_rounded, 'Absent', '$absent', LightModeColors.lightError),
                    const SizedBox(height: 8),
                    _buildStatRow(Icons.schedule_rounded, 'Late', '$late', LightModeColors.accentOrange),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: LightModeColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total School Days',
                    style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant)),
                Text('$total',
                    style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
            style: context.textStyles.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant))),
        Text(value,
            style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text('No attendance records found',
            style: context.textStyles.bodyMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant)),
      ),
    );
  }

  List<Widget> _buildHistoryMonths() {
    final months = _history!.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];

    for (final month in months) {
      final records = _history![month]!;
      final monthLabel = _formatMonth(month);
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(monthLabel,
                          style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600)),
                      Text('${records.length} days',
                          style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant)),
                    ],
                  ),
                ),
                ...records.map((r) {
                  final date = r['date'] as String? ?? '';
                  final status = r['status'] as String? ?? 'present';
                  final subject = r['subject_name'] as String? ?? '';
                  
                  final statusColor = status == 'present'
                      ? LightModeColors.accentGreen
                      : status == 'late'
                          ? LightModeColors.accentOrange
                          : LightModeColors.lightError;
                  final statusIcon = status == 'present'
                      ? Icons.check_circle_rounded
                      : status == 'late'
                          ? Icons.schedule_rounded
                          : Icons.cancel_rounded;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 10),
                        Text(_formatDate(date),
                            style: context.textStyles.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        if (subject.isNotEmpty)
                          Text(subject,
                              style: context.textStyles.bodySmall?.copyWith(
                                  color: LightModeColors.lightOnSurfaceVariant)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(status[0].toUpperCase() + status.substring(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              )),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  String _formatMonth(String monthStr) {
    try {
      final date = DateTime.parse('$monthStr-01');
      return DateFormat('MMMM yyyy').format(date);
    } catch (_) {
      return monthStr;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
