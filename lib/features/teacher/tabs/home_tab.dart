import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/teacher/teacher_dashboard_service.dart';
import 'package:alara/theme.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  TeacherDashboardData? _dashboardData;
  List<ClassInfo> _myClasses = [];
  bool _isLoading = true;
  String? _error;
  String? _profilePictureUrl;

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
      final service = TeacherDashboardService();
      final results = await Future.wait([
        service.getDashboardData(),
        service.getMyClasses(),
        service.getProfilePictureUrl(),
      ]);

      if (mounted) {
        setState(() {
          _dashboardData = results[0] as TeacherDashboardData;
          _myClasses = results[1] as List<ClassInfo>;
          _profilePictureUrl = results[2] as String?;
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
          // Top bar with profile (pinned)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TopBarDelegate(
              minHeight: topBarHeight,
              maxHeight: topBarHeight,
              child: _buildTopBar(user),
            ),
          ),
          // Main content
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
                  _buildGenderDistribution(),
                  const SizedBox(height: 24),
                  _buildMyClassesSection(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LightModeColors.lightPrimary,
            LightModeColors.lightSecondary
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
                  // Profile picture - tap to navigate to profile page
                  GestureDetector(
                    onTap: () => context.push('/teacher/profile'),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _profilePictureUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _profilePictureUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person,
                                      color: Colors.white, size: 24),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  child: Text(
                                    (user?.name ?? 'T')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.white.withValues(alpha: 0.2),
                                child: Center(
                                  child: Text(
                                    (user?.name ?? 'T')
                                        .substring(0, 1)
                                        .toUpperCase(),
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
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name ?? 'Teacher',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notifications
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 22),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
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

  Widget _buildStatsRow() {
    if (_dashboardData == null) return const SizedBox.shrink();
    final data = _dashboardData!;

    return Row(
      children: [
        Expanded(
            child: _StatCard(
          icon: Icons.school_outlined,
          label: 'Classes',
          value: '${data.myClasses}',
          color: LightModeColors.accentBlue,
          bgColor: LightModeColors.accentBlue.withValues(alpha: 0.1),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.people_outline,
          label: 'Students',
          value: '${data.myStudents}',
          color: LightModeColors.accentGreen,
          bgColor: LightModeColors.accentGreen.withValues(alpha: 0.1),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.assignment_outlined,
          label: 'Active',
          value: '${data.activeAssignments}',
          color: LightModeColors.accentOrange,
          bgColor: LightModeColors.accentOrange.withValues(alpha: 0.1),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.rate_review_outlined,
          label: 'Pending',
          value: '${data.pendingReviews}',
          color: LightModeColors.accentPink,
          bgColor: LightModeColors.accentPink.withValues(alpha: 0.1),
        )),
      ],
    );
  }

  Widget _buildAttendanceCard() {
    if (_dashboardData == null) return const SizedBox.shrink();
    final att = _dashboardData!.attendanceOverview;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                'Last 30 days',
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Flexible(
                    flex: att.present,
                    child: Container(color: LightModeColors.accentGreen),
                  ),
                  Flexible(
                    flex: att.late,
                    child: Container(color: LightModeColors.accentOrange),
                  ),
                  Flexible(
                    flex: att.absent,
                    child: Container(color: LightModeColors.lightError),
                  ),
                  if (att.total == 0)
                    Flexible(
                        flex: 1,
                        child: Container(color: LightModeColors.lightOutline)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _LegendItem(
                  color: LightModeColors.accentGreen,
                  label: 'Present',
                  value: '${att.present}'),
              const SizedBox(width: 12),
              _LegendItem(
                  color: LightModeColors.accentOrange,
                  label: 'Late',
                  value: '${att.late}'),
              const SizedBox(width: 12),
              _LegendItem(
                  color: LightModeColors.lightError,
                  label: 'Absent',
                  value: '${att.absent}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDistribution() {
    if (_dashboardData == null) return const SizedBox.shrink();
    final gender = _dashboardData!.genderDistribution;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Distribution',
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: LightModeColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Male
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: LightModeColors.accentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.male,
                          color: LightModeColors.accentBlue, size: 28),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${gender.male}',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.accentBlue,
                            ),
                          ),
                          Text(
                            'Boys',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Female
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: LightModeColors.accentPink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          color: LightModeColors.accentPink, size: 28),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${gender.female}',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.accentPink,
                            ),
                          ),
                          Text(
                            'Girls',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyClassesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Classes',
          style: context.textStyles.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: LightModeColors.lightOnSurface,
          ),
        ),
        const SizedBox(height: 14),
        if (_myClasses.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: LightModeColors.lightOutline.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                'No classes assigned yet',
                style: context.textStyles.bodyMedium?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...List.generate(_myClasses.length, (index) {
            final cls = _myClasses[index];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index < _myClasses.length - 1 ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            LightModeColors.lightPrimary.withValues(alpha: 0.8),
                            LightModeColors.lightSecondary
                                .withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          cls.name.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                            cls.name,
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cls.studentCount} students · ${cls.subjectsTaught.length} subjects',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cls.isFormTutor
                            ? LightModeColors.accentGreen.withValues(alpha: 0.1)
                            : LightModeColors.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cls.isFormTutor ? 'Form Tutor' : 'Subject',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cls.isFormTutor
                              ? LightModeColors.accentGreen
                              : LightModeColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Icon(Icons.cloud_off,
                size: 64,
                color: LightModeColors.lightOnSurfaceVariant
                    .withValues(alpha: 0.5)),
          ),
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
            color: Colors.black.withValues(alpha: 0.04),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $value',
          style: context.textStyles.bodySmall?.copyWith(
            color: LightModeColors.lightOnSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
