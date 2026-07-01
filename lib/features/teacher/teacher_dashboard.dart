import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/teacher/teacher_dashboard_service.dart';
import 'package:alara/theme.dart';
import 'package:alara/core/offline/ui/sync_widgets.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  late Future<TeacherDashboardData> _dashboardFuture;
  final TeacherDashboardService _dashboardService = TeacherDashboardService();

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _dashboardService.getDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: AppSpacing.paddingLg,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      backgroundImage: (user?.profileImage?.trim().isNotEmpty ?? false)
                          ? NetworkImage(user!.profileImage!.trim())
                          : null,
                      child: (user?.profileImage?.trim().isNotEmpty ?? false)
                          ? null
                          : Text(
                              (user?.name.isNotEmpty ?? false)
                                  ? user!.name.substring(0, 1).toUpperCase()
                                  : 'T',
                              style: context.textStyles.headlineMedium?.copyWith(
                                color: LightModeColors.lightPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Teacher',
                            style: context.textStyles.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => context.push('/teacher/communication'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: LightModeColors.lightBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.xl),
                      topRight: Radius.circular(AppRadius.xl),
                    ),
                  ),
                  child: FutureBuilder<TeacherDashboardData>(
                    future: _dashboardFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return _DashboardErrorState(
                          onRetry: () {
                            setState(() {
                              _dashboardFuture = _dashboardService.getDashboardData();
                            });
                          },
                        );
                      }

                      final dashboardData = snapshot.data;
                      if (dashboardData == null) {
                        return const _DashboardEmptyState();
                      }

                      return SingleChildScrollView(
                        padding: AppSpacing.paddingLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const OfflineBanner(),
                            const SyncStatusCard(),
                            StatsCard(data: dashboardData),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Quick Actions',
                              style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const QuickActionsGrid(),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'My Assigned Classes',
                                  style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/teacher/timetable'),
                                  child: const Text('View All'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TodayScheduleCard(classes: dashboardData.assignedClasses),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsCard extends StatelessWidget {
  final TeacherDashboardData data;

  const StatsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Overview',
            style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.people_outline,
                  label: 'Students',
                  value: '${data.summary.totalStudents}',
                  color: LightModeColors.accentBlue,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.class_outlined,
                  label: 'Classes',
                  value: '${data.summary.totalClasses}',
                  color: LightModeColors.accentGreen,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.assignment_outlined,
                  label: 'Subjects',
                  value: '${data.summary.totalSubjectAssignments}',
                  color: LightModeColors.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
        ),
      ],
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem('Attendance', Icons.how_to_reg, LightModeColors.accentBlue, '/teacher/attendance'),
      _ActionItem('AI Questions', Icons.psychology, LightModeColors.accentPink, '/teacher/ai-questions'),
      _ActionItem('Assignments', Icons.assignment, LightModeColors.accentOrange, '/teacher/assignments'),
      _ActionItem('Performance', Icons.analytics, LightModeColors.accentGreen, '/teacher/performance'),
      _ActionItem('Timetable', Icons.calendar_today, LightModeColors.lightPrimary, '/teacher/timetable'),
      _ActionItem('Messages', Icons.chat_bubble_outline, LightModeColors.lightTertiary, '/teacher/communication'),
      _ActionItem('Grading', Icons.grade, LightModeColors.accentOrange, '/teacher/grading'),
      _ActionItem('Materials', Icons.library_books, LightModeColors.accentBlue, '/teacher/assignments'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.68,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: () => context.push(action.route),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(action.icon, color: action.color, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Center(
                  child: Text(
                    action.title,
                    style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _ActionItem(this.title, this.icon, this.color, this.route);
}

class TodayScheduleCard extends StatelessWidget {
  final List<AssignedClass> classes;

  const TodayScheduleCard({super.key, required this.classes});

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          'No assigned classes found.',
          style: context.textStyles.bodyMedium,
        ),
      );
    }

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(classes.length, (index) {
          final assignedClass = classes[index];
          final colors = [
            LightModeColors.accentBlue,
            LightModeColors.accentGreen,
            LightModeColors.accentOrange,
            LightModeColors.accentPink,
          ];
          final color = colors[index % colors.length];

          return Column(
            children: [
              _ScheduleItem(assignedClass: assignedClass, color: color),
              if (index != classes.length - 1) const Divider(height: AppSpacing.lg),
            ],
          );
        }),
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final AssignedClass assignedClass;
  final Color color;

  const _ScheduleItem({required this.assignedClass, required this.color});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if ((assignedClass.levelName ?? '').isNotEmpty) assignedClass.levelName!,
      '${assignedClass.studentCount} students',
      if (assignedClass.isFormTutor) 'Form Tutor',
    ];

    return Row(
      children: [
        Container(
          width: 4,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignedClass.className,
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleParts.join(' • '),
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _DashboardErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: LightModeColors.accentOrange),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load dashboard data.',
              style: context.textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Text(
          'No dashboard data available.',
          style: context.textStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
