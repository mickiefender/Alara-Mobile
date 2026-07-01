import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/student/tabs/home_tab.dart';
import 'package:alara/features/student/tabs/timetable_tab.dart';
import 'package:alara/features/student/tabs/results_tab.dart';
import 'package:alara/features/student/student_ai_assistant_screen.dart';
import 'package:alara/core/models/user.dart';
import 'package:alara/theme.dart';

class StudentNavShell extends StatefulWidget {
  const StudentNavShell({super.key});

  @override
  State<StudentNavShell> createState() => _StudentNavShellState();
}

class _StudentNavShellState extends State<StudentNavShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _tabs = const [
    HomeTab(),
    TimetableTab(),
    ResultsTab(),
    StudentAiAssistantScreen(),
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
            color: Colors.black.withValues(alpha: 0.06),
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
              icon: Icons.calendar_month_rounded,
              label: 'Timetable',
              isActive: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Results',
              isActive: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
              isCenter: true,
            ),
            _NavItem(
              icon: Icons.smart_toy_rounded,
              label: 'AI',
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
    final schoolName = currentUser?.schoolName?.trim();
    final displaySchoolName =
        (schoolName != null && schoolName.isNotEmpty) ? schoolName : 'School';
    final schoolLogoUrl = currentUser?.schoolLogo;
    final currentLocation = GoRouterState.of(context).uri.toString();

    // Helper to build logo widget
    Widget _buildSchoolLogo() {
      const defaultAssetPath = 'assets/Alara-logo.png';
      
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
              color: LightModeColors.lightPrimary,
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
          color: LightModeColors.lightPrimary,
          size: 28,
        ),
      );
    }

return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: LightModeColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildSchoolLogo(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      displaySchoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleLarge?.copyWith(
                        color: LightModeColors.lightOnSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                children: [
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    isSelected: currentLocation == '/student/profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/profile');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.assignment_outlined,
                    title: 'Assignments',
                    isSelected: currentLocation == '/student/assignments',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/assignments');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    title: 'Materials',
                    isSelected: currentLocation == '/student/materials',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/materials');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.checklist_rtl_rounded,
                    title: 'Attendance',
                    isSelected: currentLocation == '/student/attendance',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/attendance');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.campaign_outlined,
                    title: 'Announcements',
                    isSelected: currentLocation == '/student/announcements',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/announcements');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Fees',
                    isSelected: currentLocation == '/student/fees',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/fees');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.assessment_outlined,
                    title: 'Results',
                    isSelected: currentLocation == '/student/results' || _currentIndex == 2,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/student/results');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Timetable',
                    isSelected: currentLocation == '/student/timetable' || _currentIndex == 1,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.smart_toy_rounded,
                    title: 'AI Assistant',
                    isSelected: currentLocation == '/student/ai-assistant' || _currentIndex == 3,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _currentIndex = 3);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    isSelected: false,
                    onTap: () async {
                      final auth = context.read<AuthProvider>();
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      await auth.logout();
                      if (!mounted) return;
                      router.go('/login');
                    },
                  ),
                  const SizedBox(height: 14),
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 10),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help and Feedback',
                    isSelected: false,
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = LightModeColors.lightPrimary.withValues(alpha: 0.12);
    final selectedColor = LightModeColors.lightPrimary;
    final defaultIconColor = LightModeColors.lightPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Icon(
                    icon,
                    size: 21,
                    color: isSelected ? selectedColor : defaultIconColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? selectedColor : Colors.black87,
                  ),
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
                      colors: [
                        LightModeColors.lightPrimary,
                        LightModeColors.lightSecondary
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            LightModeColors.lightPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
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
                        ? LightModeColors.lightPrimary.withValues(alpha: 0.1)
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
