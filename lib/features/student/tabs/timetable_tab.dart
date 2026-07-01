import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/core/models/timetable.dart';
import 'package:alara/theme.dart';

class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key});

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab>
    with SingleTickerProviderStateMixin {
  final StudentService _service = StudentService();

  late TabController _tabController;
  Map<String, List<TimetableEntry>> _timetableByDay = {};
  bool _isLoading = true;

  static const List<String> _dayNames = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday'
  ];
  static const List<String> _dayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dayNames.length, vsync: this);
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    setState(() => _isLoading = true);

    try {
      final timetableByDay = await _service.getTimetableByDay();
      if (mounted) {
        setState(() {
          _timetableByDay = timetableByDay;
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
        title: const Text('My Timetable', style: TextStyle(color: Colors.white)),
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
            onPressed: _isLoading ? null : _loadTimetable,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: LightModeColors.lightPrimary,
              unselectedLabelColor: Colors.white.withOpacity(0.8),
              labelStyle: context.textStyles.labelLarge?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 13,
              ),
              tabs: _dayAbbreviations.map((day) => Tab(text: day)).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LightModeColors.lightPrimary))
          : TabBarView(
              controller: _tabController,
              children: List.generate(_dayNames.length, (i) => _buildDayContent(i)),
            ),
    );
  }

  Widget _buildDayContent(int index) {
    final entries = _timetableByDay[_dayNames[index]] ?? [];
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 64,
                color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No classes scheduled',
                style: context.textStyles.titleMedium?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTimetable,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          final colors = [
            LightModeColors.lightPrimary, LightModeColors.accentBlue,
            LightModeColors.accentGreen, LightModeColors.accentOrange,
            LightModeColors.accentPink, LightModeColors.lightSecondary,
          ];
          final color = colors[i % colors.length];
          final timeRange = '${_formatTime(entry.startTime)} – ${_formatTime(entry.endTime)}';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LightModeColors.lightOutline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 5, height: 90,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getSubjectIcon(entry.subjectName ?? ''),
                        size: 22, color: color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.subjectName ?? 'Unknown',
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 13,
                                  color: LightModeColors.accentBlue),
                              const SizedBox(width: 4),
                              Text(timeRange,
                                  style: context.textStyles.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: LightModeColors.accentBlue,
                                      fontSize: 11)),
                              if (entry.venue != null) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.location_on_rounded, size: 13,
                                    color: LightModeColors.accentOrange),
                                const SizedBox(width: 4),
                                Text(entry.venue!,
                                    style: context.textStyles.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: LightModeColors.accentOrange,
                                        fontSize: 11)),
                              ],
                            ],
                          ),
                          if (entry.teacherName != null && entry.teacherName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline, size: 13,
                                      color: LightModeColors.lightOnSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(entry.teacherName!,
                                      style: context.textStyles.bodySmall?.copyWith(
                                          color: LightModeColors.lightOnSurfaceVariant,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20,
                        color: LightModeColors.lightOutline),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$displayHour:$minute $period';
      }
      return time;
    } catch (_) {
      return time;
    }
  }

  IconData _getSubjectIcon(String name) {
    final l = name.toLowerCase();
    if (l.contains('math')) return Icons.functions_rounded;
    if (l.contains('english') || l.contains('literature')) return Icons.menu_book_rounded;
    if (l.contains('science') || l.contains('physics') || l.contains('chemistry') || l.contains('biology')) return Icons.science_rounded;
    if (l.contains('history')) return Icons.history_rounded;
    if (l.contains('geography')) return Icons.explore_rounded;
    if (l.contains('art') || l.contains('creative')) return Icons.palette_rounded;
    if (l.contains('music')) return Icons.music_note_rounded;
    if (l.contains('pe') || l.contains('sport') || l.contains('physical')) return Icons.fitness_center_rounded;
    if (l.contains('ict') || l.contains('computer') || l.contains('technology')) return Icons.computer_rounded;
    if (l.contains('religion') || l.contains('religious') || l.contains('rme')) return Icons.church_rounded;
    if (l.contains('french')) return Icons.language_rounded;
    if (l.contains('social')) return Icons.groups_rounded;
    return Icons.book_rounded;
  }
}
