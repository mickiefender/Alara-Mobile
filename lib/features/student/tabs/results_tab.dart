import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/theme.dart';

class ResultsTab extends StatefulWidget {
  const ResultsTab({super.key});

  @override
  State<ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<ResultsTab> {
  final StudentService _service = StudentService();
  List<StudentSubjectPerformance>? _results;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      final results = await _service.getResults();
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Results', style: TextStyle(color: Colors.white)),
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _isLoading ? null : _loadResults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LightModeColors.lightPrimary))
          : _results == null || _results!.isEmpty
              ? _buildEmptyState()
              : _buildResultsContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 80,
              color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No results available yet',
              style: context.textStyles.titleMedium?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Results will appear once grades are published',
              style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    final overall = _results!.isEmpty
        ? 0.0
        : _results!.map((r) => (r.score / r.maxScore) * 100).reduce((a, b) => a + b) /
            _results!.length;

    return RefreshIndicator(
      onRefresh: _loadResults,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Overall Performance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LightModeColors.lightPrimary.withOpacity(0.1),
                  LightModeColors.lightSecondary.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LightModeColors.lightPrimary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80, height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80, height: 80,
                        child: CircularProgressIndicator(
                          value: overall / 100,
                          strokeWidth: 8,
                          backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            overall >= 80
                                ? LightModeColors.accentGreen
                                : overall >= 50
                                    ? LightModeColors.accentOrange
                                    : LightModeColors.lightError,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${overall.toStringAsFixed(0)}%',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: overall >= 80
                                  ? LightModeColors.accentGreen
                                  : overall >= 50
                                      ? LightModeColors.accentOrange
                                      : LightModeColors.lightError,
                            ),
                          ),
                          Text('Avg', style: TextStyle(
                              fontSize: 10,
                              color: LightModeColors.lightOnSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Performance',
                          style: context.textStyles.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${_results!.length} subjects',
                          style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Grade: ${_getGrade(overall)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.lightPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Subject Performance',
              style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...List.generate(_results!.length, (i) {
            final result = _results![i];
            final pct = result.maxScore > 0
                ? (result.score / result.maxScore) * 100
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
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
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              result.subjectName.substring(0, 2).toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.lightPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(result.subjectName,
                                  style: context.textStyles.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                'Score: ${result.score.toStringAsFixed(0)}/${result.maxScore.toStringAsFixed(0)}',
                                style: context.textStyles.bodySmall?.copyWith(
                                    color: LightModeColors.lightOnSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getGradeColor(pct).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result.grade.isNotEmpty ? result.grade : _getGrade(pct),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getGradeColor(pct),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(_getGradeColor(pct)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: context.textStyles.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _getGradeColor(pct),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getGrade(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C+';
    if (pct >= 40) return 'C';
    return 'D';
  }

  Color _getGradeColor(double pct) {
    if (pct >= 80) return LightModeColors.accentGreen;
    if (pct >= 60) return LightModeColors.accentBlue;
    if (pct >= 40) return LightModeColors.accentOrange;
    return LightModeColors.lightError;
  }
}
