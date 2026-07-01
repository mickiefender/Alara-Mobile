import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/theme.dart';
import 'package:alara/services/timetable_service.dart';
import 'package:alara/core/models/timetable.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with SingleTickerProviderStateMixin {
  final TimetableService _service = TimetableService();

  late TabController _tabController;
  Map<String, List<TimetableEntry>> _timetableByDay = {};
  bool _isLoading = true;
  String? _errorMessage;

  // Current week date range
  final DateTime _weekStart = _getWeekStart();

  static DateTime _getWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - DateTime.monday;
    return DateTime(now.year, now.month, now.day - daysFromMonday);
  }

  static const List<String> _dayNames = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday'
  ];

  static const List<String> _dayLabels = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
  ];

  static const List<String> _dayAbbreviations = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri'
  ];

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final timetableByDay = await _service.getTeacherTimetableByDay();
      if (mounted) {
        setState(() {
          _timetableByDay = timetableByDay;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load timetable. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  List<TimetableEntry> _getEntriesForDay(int tabIndex) {
    final dayKey = _dayNames[tabIndex];
    return _timetableByDay[dayKey] ?? [];
  }

  int _getTotalClassesForWeek() {
    int count = 0;
    for (final day in _dayNames) {
      count += (_timetableByDay[day] ?? []).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'My Timetable',
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
              colors: [
                LightModeColors.lightPrimary,
                LightModeColors.lightSecondary,
              ],
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
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: context.textStyles.labelLarge?.copyWith(
                fontSize: 13,
              ),
              tabs: _dayAbbreviations.map((day) => Tab(text: day)).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: LightModeColors.lightPrimary,
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildBody(),
    );
  }

  Widget _buildErrorState() {
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
                color: LightModeColors.lightError.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: LightModeColors.lightError,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: context.textStyles.titleMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadTimetable,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Week header and stats summary
        _buildWeekHeader(),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(_dayNames.length, (index) {
              return _buildDayContent(index);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final totalClasses = _getTotalClassesForWeek();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: Colors.white,
      child: Row(
        children: [
          // Date range display
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(_weekStart),
                  style: context.textStyles.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightPrimary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  DateFormat('d').format(_weekStart),
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.lightPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(_weekStart.add(const Duration(days: 4))),
                  style: context.textStyles.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightPrimary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  DateFormat('d').format(_weekStart.add(const Duration(days: 4))),
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.lightPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: LightModeColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: LightModeColors.lightPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalClasses classes',
                  style: context.textStyles.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightOnSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayContent(int tabIndex) {
    final entries = _getEntriesForDay(tabIndex);

    if (entries.isEmpty) {
      return _buildEmptyDay(tabIndex);
    }

    return RefreshIndicator(
      onRefresh: _loadTimetable,
      color: LightModeColors.lightPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          // Show time separator if needed
          final showTimeSeparator = index == 0 || entries[index - 1].startTime != entry.startTime;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTimeSeparator)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
                  child: _buildTimeSlotLabel(entry.startTime),
                ),
              _buildClassCard(entry, index),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeSlotLabel(String startTime) {
    final displayTime = _formatTimeDisplay(startTime);
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: LightModeColors.lightPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          displayTime,
          style: context.textStyles.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: LightModeColors.lightOnSurface,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(TimetableEntry entry, int index) {
    final subjectColor = _getSubjectColor(index);
    final timeRange = '${_formatTimeDisplay(entry.startTime)} – ${_formatTimeDisplay(entry.endTime)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LightModeColors.lightOutline,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
            child: Row(
              children: [
                // Colored accent strip
                Container(
                  width: 5,
                  height: 90,
                  decoration: BoxDecoration(
                    color: subjectColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Subject icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: subjectColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      _getSubjectIcon(entry.subjectName ?? ''),
                      size: 22,
                      color: subjectColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Subject name
                      Text(
                        entry.subjectName ?? 'Unknown Subject',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: LightModeColors.lightOnSurface,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Class row (teacher name removed — only own classes shown)
                      Row(
                        children: [
                          if (entry.className != null) ...[
                            Icon(
                              Icons.school_rounded,
                              size: 13,
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                entry.className!,
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: LightModeColors.lightOnSurfaceVariant,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Time and venue row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: LightModeColors.accentBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeRange,
                            style: context.textStyles.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.accentBlue,
                              fontSize: 11,
                            ),
                          ),
                          if (entry.venue != null && entry.venue!.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: LightModeColors.accentOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.venue!,
                              style: context.textStyles.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: LightModeColors.accentOrange,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: LightModeColors.lightOutline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDay(int tabIndex) {
    final dayName = _dayLabels[tabIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: LightModeColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 40,
                color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No classes on $dayName',
              style: context.textStyles.titleMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your day off! 🎉',
              style: context.textStyles.bodyMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeDisplay(String time) {
    try {
      // Handle formats like "08:00" or "08:00:00"
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

  Color _getSubjectColor(int index) {
    final colors = [
      LightModeColors.lightPrimary,
      LightModeColors.accentBlue,
      LightModeColors.accentGreen,
      LightModeColors.accentOrange,
      LightModeColors.accentPink,
      LightModeColors.lightSecondary,
      LightModeColors.accentBlue.withBlue(180),
      LightModeColors.accentGreen.withRed(50),
    ];
    return colors[index % colors.length];
  }

  IconData _getSubjectIcon(String subjectName) {
    final lower = subjectName.toLowerCase();
    if (lower.contains('math')) return Icons.functions_rounded;
    if (lower.contains('english') || lower.contains('literature')) return Icons.menu_book_rounded;
    if (lower.contains('science') || lower.contains('physics') || lower.contains('chemistry') || lower.contains('biology')) return Icons.science_rounded;
    if (lower.contains('history')) return Icons.history_rounded;
    if (lower.contains('geography')) return Icons.explore_rounded;
    if (lower.contains('art') || lower.contains('creative')) return Icons.palette_rounded;
    if (lower.contains('music')) return Icons.music_note_rounded;
    if (lower.contains('pe') || lower.contains('sport') || lower.contains('physical')) return Icons.fitness_center_rounded;
    if (lower.contains('ict') || lower.contains('computer') || lower.contains('technology')) return Icons.computer_rounded;
    if (lower.contains('religion') || lower.contains('religious') || lower.contains('rme')) return Icons.church_rounded;
    if (lower.contains('french')) return Icons.language_rounded;
    if (lower.contains('social')) return Icons.groups_rounded;
    if (lower.contains('science')) return Icons.science_rounded;
    return Icons.book_rounded;
  }
}
