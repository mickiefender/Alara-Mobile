import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/theme.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

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
                      child: ClipOval(
                        child: (user?.profileImage?.trim().isNotEmpty ?? false)
                            ? CachedNetworkImage(
                                imageUrl: user!.profileImage!.trim(),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _studentInitialAvatar(context, user?.name),
                              )
                            : _studentInitialAvatar(context, user?.name),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Student',
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
                      onPressed: () => context.push('/student/announcements'),
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
                  child: SingleChildScrollView(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AttendanceCard(),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Quick Access',
                          style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const QuickActionsGrid(),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Upcoming Assignments',
                          style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const UpcomingAssignmentsCard(),
                      ],
                    ),
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

Widget _studentInitialAvatar(BuildContext context, String? name) {
  final initial = (name != null && name.isNotEmpty) ? name.substring(0, 1).toUpperCase() : 'S';
  return Container(
    width: 60,
    height: 60,
    color: Colors.white,
    alignment: Alignment.center,
    child: Text(
      initial,
      style: context.textStyles.headlineMedium?.copyWith(
        color: LightModeColors.lightPrimary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [LightModeColors.accentGreen, Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Rate',
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '92%',
                  style: context.textStyles.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.8), size: 20),
        ],
      ),
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem('Timetable', Icons.calendar_today, LightModeColors.accentBlue, '/student/timetable'),
      _ActionItem('Results', Icons.bar_chart, LightModeColors.accentGreen, '/student/results'),
      _ActionItem('Assignments', Icons.assignment, LightModeColors.accentOrange, '/student/assignments'),
      _ActionItem('Materials', Icons.library_books, LightModeColors.lightTertiary, '/student/materials'),
      _ActionItem('Attendance', Icons.how_to_reg, LightModeColors.accentPink, '/student/attendance'),
      _ActionItem('Announcements', Icons.campaign, LightModeColors.lightPrimary, '/student/announcements'),
      _ActionItem('Fees', Icons.payment, LightModeColors.accentOrange, '/student/fees'),
      _ActionItem('Profile', Icons.person, Colors.grey, '/student/profile'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: () => context.push(action.route),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(action.icon, color: action.color, size: 28),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                action.title,
                style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

class UpcomingAssignmentsCard extends StatelessWidget {
  const UpcomingAssignmentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LightModeColors.lightOutline),
      ),
      child: Column(
        children: [
          _AssignmentItem('Mathematics Assignment 5', 'Due: Tomorrow', LightModeColors.accentBlue),
          const Divider(height: AppSpacing.lg),
          _AssignmentItem('Physics Lab Report', 'Due: 3 days', LightModeColors.accentGreen),
          const Divider(height: AppSpacing.lg),
          _AssignmentItem('English Essay', 'Due: 5 days', LightModeColors.accentOrange),
        ],
      ),
    );
  }
}

class _AssignmentItem extends StatelessWidget {
  final String title;
  final String dueDate;
  final Color color;

  const _AssignmentItem(this.title, this.dueDate, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(Icons.assignment, color: color, size: 24),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                dueDate,
                style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_ios, size: 16, color: LightModeColors.lightOnSurfaceVariant),
      ],
    );
  }
}
