import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/teacher/tabs/home_tab.dart';
import 'package:alara/features/teacher/tabs/attendance_tab.dart';
import 'package:alara/features/teacher/tabs/assignments_tab.dart';
import 'package:alara/features/teacher/tabs/messages_tab.dart';
import 'package:alara/core/models/user.dart';
import 'package:alara/theme.dart';

class TeacherNavShell extends StatefulWidget {
  const TeacherNavShell({super.key});

  @override
  State<TeacherNavShell> createState() => _TeacherNavShellState();
}

class _TeacherNavShellState extends State<TeacherNavShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _tabs = const [
    HomeTab(),
    AttendanceTab(),
    AssignmentsTab(),
    MessagesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      key: _scaffoldKey,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNav(),
      drawer: _buildMoreDrawer(currentUser: currentUser),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.how_to_reg_rounded,
              label: 'Attendance',
              isActive: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _NavItem(
              icon: Icons.assignment_rounded,
              label: 'Assignments',
              isActive: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
              isCenter: true,
            ),
            _NavItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              isActive: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
            _NavItem(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              isActive: false,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreDrawer({User? currentUser}) {
    final schoolName = (currentUser?.schoolName ?? '').trim().isNotEmpty
        ? currentUser!.schoolName!.trim()
        : 'School';
    final schoolLogoUrl = currentUser?.schoolLogo;
    const defaultAssetPath = 'assets/Alara-logo.png';

    // Helper to build logo widget
    Widget _buildSchoolLogo() {
      if (schoolLogoUrl != null && schoolLogoUrl.isNotEmpty) {
        // Try network image first (from API)
        return Image.network(
          schoolLogoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            defaultAssetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.school_rounded,
              color: Color(0xFF0B97B0),
              size: 28,
            ),
          ),
        );
      }
      
      // Fallback to asset
      return Image.asset(
        defaultAssetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.school_rounded,
          color: Color(0xFF0B97B0),
          size: 28,
        ),
      );
    }

return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
// School header - clean white theme
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: LightModeColors.lightBackground,
                      child: _buildSchoolLogo(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schoolName,
                          style: context.textStyles.titleLarge?.copyWith(
                            color: LightModeColors.lightOnSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser?.name ?? 'Teacher',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DrawerSectionTitle(title: 'Features'),
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'View and edit your profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/profile');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.analytics_rounded,
                    title: 'Performance',
                    subtitle: 'Student performance analytics',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/performance');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Timetable',
                    subtitle: 'Manage your schedule',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/timetable');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.psychology_rounded,
                    title: 'AI Questions',
                    subtitle: 'Generate questions with AI',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/ai-questions');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.chat_rounded,
                    title: 'Communication',
                    subtitle: 'Messages & announcements',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/communication');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.grade_rounded,
                    title: 'Grading',
                    subtitle: 'Grade assignments & exams',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/grading');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.library_books_rounded,
                    title: 'Materials',
                    subtitle: 'Learning resources',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/assignments');
                    },
                  ),
                  const SizedBox(height: 12),
                  _DrawerSectionTitle(title: 'Support'),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'App preferences',
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.sync_rounded,
                    title: 'Sync & Offline',
                    subtitle: 'Manage offline data & sync',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/sync-settings');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and contact',
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'App version & info',
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String title;

  const _DrawerSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        title,
        style: context.textStyles.labelLarge?.copyWith(
          color: LightModeColors.lightOnSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LightModeColors.lightPrimaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: LightModeColors.lightPrimary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: LightModeColors.lightOnSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.lightOnSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: LightModeColors.lightOnSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCenter;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: isCenter
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: LightModeColors.lightPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: LightModeColors.lightPrimary,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 48 : 40,
                  height: isActive ? 48 : 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? LightModeColors.lightPrimary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isActive
                        ? LightModeColors.lightPrimary
                        : LightModeColors.lightOnSurfaceVariant,
                    size: isActive ? 26 : 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? LightModeColors.lightPrimary
                        : LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
