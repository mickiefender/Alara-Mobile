import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/theme.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  final StudentService _service = StudentService();
  List<StudentAssignment>? _assignments;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final a = await _service.getAssignments();
      if (mounted) {
        setState(() {
          _assignments = a;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to fetch assignments. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Assignments', style: TextStyle(color: Colors.white)),
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
          : _error != null
              ? _buildError()
              : _assignments == null || _assignments!.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 70, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_rounded, size: 80,
            color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text('No assignments yet',
            style: context.textStyles.titleMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant)),
      ],
    ),
  );

  Widget _buildList() {
    // Sort: overdue first, then pending, then submitted
    final sorted = List<StudentAssignment>.from(_assignments!);
    sorted.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      if (a.isSubmitted != b.isSubmitted) return a.isSubmitted ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });

    final pending = sorted.where((a) => !a.isSubmitted).length;
    final overdue = sorted.where((a) => a.isOverdue).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Summary bar
          Row(
            children: [
              _summaryChip('Pending', '$pending', LightModeColors.accentOrange),
              const SizedBox(width: 8),
              _summaryChip('Overdue', '$overdue', LightModeColors.lightError),
              const SizedBox(width: 8),
              _summaryChip('Total', '${sorted.length}', LightModeColors.lightPrimary),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.map((a) => _buildAssignmentCard(a)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: color, fontSize: 20)),
            Text(label,
                style: context.textStyles.bodySmall?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(StudentAssignment a) {
    final color = a.isOverdue
        ? LightModeColors.lightError
        : a.isSubmitted
            ? LightModeColors.accentGreen
            : LightModeColors.accentOrange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: a.isOverdue ? LightModeColors.lightError.withOpacity(0.2) : LightModeColors.lightOutline,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      a.isSubmitted ? Icons.check_circle_rounded : Icons.assignment_rounded,
                      color: color, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          a.isSubmitted
                              ? 'Submitted · ${a.score?.toStringAsFixed(0) ?? "--"}/100'
                              : a.isOverdue
                                  ? 'Overdue · ${a.subjectName}'
                                  : '${a.subjectName}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.isSubmitted
                          ? 'Done'
                          : a.isOverdue
                              ? 'Late'
                              : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              if (a.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(a.description,
                    style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14,
                      color: LightModeColors.lightOnSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(a.dueDate)}',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: LightModeColors.lightOnSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (a.feedback != null && a.feedback!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.feedback_rounded, size: 14,
                            color: LightModeColors.accentBlue),
                        const SizedBox(width: 4),
                        Text('Feedback available',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.accentBlue, fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
