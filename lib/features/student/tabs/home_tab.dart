import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/core/services/notification_service.dart';
import 'package:alara/theme.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final StudentService _service = StudentService();
  StudentDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _error;

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
      final data = await _service.getDashboardData();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final topInset = MediaQuery.of(context).padding.top;
    final topBarHeight = topInset + 96;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: LightModeColors.lightPrimary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _TopBarDelegate(
              minHeight: topBarHeight,
              maxHeight: topBarHeight,
              child: _buildTopBar(user),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _buildErrorState()
                else ...[
                  const SizedBox(height: 8),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildAttendanceCard(),
                  const SizedBox(height: 24),
                  _buildPerformanceCard(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(user) {
    final profileImageUrl = _service.resolveProfileImageUrl(user?.profileImage);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LightModeColors.lightPrimary,
            LightModeColors.lightSecondary,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/student/profile'),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.white.withOpacity(0.2),
                                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white.withOpacity(0.2),
                                  child: Center(
                                    child: Text(
                                      (user?.name ?? 'S').substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.white.withOpacity(0.2),
                                child: Center(
                                  child: Text(
                                    (user?.name ?? 'S').substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name ?? 'Student',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: NotificationService.instance,
                    builder: (context, _) {
                      final unreadCount = NotificationService.instance.unreadCount;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () => context.push('/student/notifications'),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white, width: 1.2),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_dashboardData == null) return const SizedBox.shrink();
    final data = _dashboardData!;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.school_outlined,
            label: 'Classes',
            value: '${data.totalClasses}',
            color: LightModeColors.accentBlue,
            bgColor: LightModeColors.accentBlue.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.book_outlined,
            label: 'Subjects',
            value: '${data.totalSubjects}',
            color: LightModeColors.accentGreen,
            bgColor: LightModeColors.accentGreen.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.assignment_outlined,
            label: 'Pending',
            value: '${data.pendingAssignments}',
            color: LightModeColors.accentOrange,
            bgColor: LightModeColors.accentOrange.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            label: 'Avg',
            value: '${data.overallPerformance.toStringAsFixed(0)}%',
            color: LightModeColors.accentPink,
            bgColor: LightModeColors.accentPink.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard() {
    if (_dashboardData == null) return const SizedBox.shrink();
    final attPct = _dashboardData!.attendancePercentage;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Overview',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightOnSurface,
                ),
              ),
              Text(
                'This term',
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
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
                        value: attPct / 100,
                        strokeWidth: 8,
                        backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          attPct >= 90
                              ? LightModeColors.accentGreen
                              : attPct >= 75
                                  ? LightModeColors.accentOrange
                                  : LightModeColors.lightError,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${attPct.toStringAsFixed(0)}%',
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: attPct >= 90
                                ? LightModeColors.accentGreen
                                : attPct >= 75
                                    ? LightModeColors.accentOrange
                                    : LightModeColors.lightError,
                          ),
                        ),
                        Text(
                          'Present',
                          style: context.textStyles.bodySmall?.copyWith(
                            fontSize: 10,
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildMiniStat(Icons.check_circle_rounded, 'Present', '${(_dashboardData?.attendancePercentage ?? 0).toStringAsFixed(0)}%', LightModeColors.accentGreen),
                    const SizedBox(height: 8),
                    _buildMiniStat(Icons.cancel_rounded, 'Absent', '${(100 - (_dashboardData?.attendancePercentage ?? 0)).toStringAsFixed(0)}%', LightModeColors.lightError),
                    const SizedBox(height: 8),
                    _buildMiniStat(Icons.schedule_rounded, 'Late', '0%', LightModeColors.accentOrange),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/student/attendance'),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: const Text('View Full Record'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LightModeColors.lightPrimary,
                side: BorderSide(color: LightModeColors.lightPrimary.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: context.textStyles.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: LightModeColors.lightOnSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard() {
    if (_dashboardData == null) return const SizedBox.shrink();
    final perf = _dashboardData!.overallPerformance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LightModeColors.lightPrimary.withOpacity(0.05),
            LightModeColors.lightSecondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LightModeColors.lightPrimary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Performance',
                style: context.textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getGrade(perf),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.lightPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${perf.toStringAsFixed(1)}%',
                      style: context.textStyles.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightOnSurface,
                      ),
                    ),
                    Text(
                      'Average Score',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: LightModeColors.accentGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_dashboardData!.totalAssignments} Assignments',
                      style: context.textStyles.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: LightModeColors.lightOnSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/student/results'),
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text('View Results'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LightModeColors.lightPrimary,
                side: BorderSide(color: LightModeColors.lightPrimary.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C+';
    if (percentage >= 40) return 'C';
    return 'D';
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(Icons.calendar_month_rounded, 'Timetable', LightModeColors.lightPrimary, '/student/timetable'),
      _QuickAction(Icons.bar_chart_rounded, 'Results', LightModeColors.accentGreen, '/student/results'),
      _QuickAction(Icons.assignment_rounded, 'Assignments', LightModeColors.accentOrange, '/student/assignments'),
      _QuickAction(Icons.library_books_rounded, 'Materials', LightModeColors.lightTertiary, '/student/materials'),
      _QuickAction(Icons.how_to_reg_rounded, 'Attendance', LightModeColors.accentPink, '/student/attendance'),
      _QuickAction(Icons.campaign_rounded, 'News', LightModeColors.accentBlue, '/student/announcements'),
      _QuickAction(Icons.payment_rounded, 'Fees', LightModeColors.accentGreen, '/student/fees'),
      _QuickAction(Icons.person_rounded, 'Profile', Colors.grey, '/student/profile'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: LightModeColors.lightOnSurface,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () => context.push(action.route),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.icon, color: action.color, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.title,
                    style: context.textStyles.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 64, color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Could not load dashboard',
            style: context.textStyles.titleMedium?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to retry',
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _TopBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TopBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final Color color;
  final String route;

  _QuickAction(this.icon, this.title, this.color, this.route);
}