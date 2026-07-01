import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:alara/theme.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/core/services/onboarding_service.dart';
import 'package:alara/features/onboarding/onboarding_pages.dart';
import 'package:alara/nav.dart';

class OnboardingScreen extends StatefulWidget {
  final String? role;

  const OnboardingScreen({super.key, this.role});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late final List<OnboardingPage> _pages;
  int _currentPage = 0;
  String? _selectedRole;
  bool _showRoleSelection = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    
    // If role is provided, use it directly
    // If role is null, show role selection first
    if (widget.role != null && widget.role!.isNotEmpty) {
      _selectedRole = widget.role;
      _pages = widget.role == 'teacher'
          ? TeacherOnboardingPages.pages
          : StudentOnboardingPages.pages;
    } else {
      _showRoleSelection = true;
      _pages = [];
    }
  }

  void _onRoleSelected(String role) {
    setState(() {
      _selectedRole = role;
      _showRoleSelection = false;
      _pages = role == 'teacher'
          ? TeacherOnboardingPages.pages
          : StudentOnboardingPages.pages;
      // Reset page controller to start
      _pageController.jumpToPage(0);
      _currentPage = 0;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

Future<void> _completeOnboarding() async {
    // Use the selected role (either from widget.role or _selectedRole)
    final role = _selectedRole ?? widget.role ?? 'student';
    
    // Complete onboarding in storage
    await OnboardingService.instance.completeOnboarding(role);
    
    // Update AuthProvider state so router doesn't redirect back to onboarding
    if (mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.completeOnboarding();
      
      // Navigate to the appropriate dashboard
      if (role == 'teacher') {
        context.go(AppRoutes.teacherDashboard);
      } else {
        context.go(AppRoutes.studentDashboard);
      }
    }
  }

@override
  Widget build(BuildContext context) {
    // Show role selection screen if no role is provided
    if (_showRoleSelection) {
      return _buildRoleSelectionScreen(context);
    }
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LightModeColors.lightBackground,
              Color(0xFFF3F4F6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: context.textStyles.labelLarge?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _OnboardingPageContent(
                      page: _pages[index],
                    );
                  },
                ),
              ),

              // Page indicator and buttons
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
// Page indicator
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: _pages.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: 10,
                        dotWidth: 10,
                        spacing: 8,
                        activeDotColor: LightModeColors.lightPrimary,
                        dotColor: LightModeColors.lightOutline,
                        expansionFactor: 2.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _nextPage,
                        style: FilledButton.styleFrom(
                          padding: AppSpacing.verticalMd,
                          backgroundColor: LightModeColors.lightPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            key: ValueKey(_currentPage == _pages.length - 1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelectionScreen(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                // Title
                Text(
                  'Welcome to Alara',
                  style: context.textStyles.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Subtitle
                Text(
                  'Are you a teacher or student?',
                  style: context.textStyles.titleLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                // Role selection buttons
                _RoleSelectionCard(
                  icon: Icons.person_outline,
                  title: 'Teacher',
                  description: 'Manage attendance, grades, and students',
                  onTap: () => _onRoleSelected('teacher'),
                ),
                const SizedBox(height: AppSpacing.lg),
                _RoleSelectionCard(
                  icon: Icons.school_outlined,
                  title: 'Student',
                  description: 'View assignments, attendance, and results',
                  onTap: () => _onRoleSelected('student'),
                ),
                
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleSelectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: LightModeColors.lightPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: LightModeColors.lightOnSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  final OnboardingPage page;

  const _OnboardingPageContent({required this.page});

@override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
// SVG container with transparent background (free form)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Container(
                width: 300,
                height: 300,
                padding: const EdgeInsets.all(30),
                child: SvgPicture.asset(
                  page.svgAsset,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: child,
                );
              },
              child: Text(
                page.title,
                style: context.textStyles.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.lightOnSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            Text(
              page.description,
              style: context.textStyles.bodyLarge?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
