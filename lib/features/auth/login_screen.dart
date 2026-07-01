import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/core/services/onboarding_service.dart';
import 'package:alara/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = 'teacher';

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _selectedRole,
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (success) {
        // Check if onboarding is completed for this role
        final onboardingCompleted = await OnboardingService.instance.isOnboardingCompleted(_selectedRole);
        
        if (!onboardingCompleted) {
          // Redirect to onboarding
          context.go('/onboarding?role=$_selectedRole');
        } else {
          // Go directly to dashboard
          if (authProvider.isTeacher) {
            context.go('/teacher/dashboard');
          } else if (authProvider.isStudent) {
            context.go('/student/dashboard');
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LightModeColors.lightPrimary,
              LightModeColors.lightSecondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/Alara-logo-no-bg.png',
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Alara',
                    style: context.textStyles.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                 
                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: context.textStyles.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'teacher',
                                label: Text('Teacher'),
                                icon: Icon(Icons.person_outline),
                              ),
                              ButtonSegment<String>(
                                value: 'student',
                                label: Text('Student'),
                                icon: Icon(Icons.school_outlined),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (Set<String> selection) {
                              setState(() {
                                _selectedRole = selection.first;
                                _identifierController.clear();
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: _selectedRole == 'teacher'
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: _selectedRole == 'teacher' ? 'Email' : 'Student ID',
                              prefixIcon: Icon(
                                _selectedRole == 'teacher'
                                    ? Icons.email_outlined
                                    : Icons.badge_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _selectedRole == 'teacher'
                                    ? 'Please enter your email'
                                    : 'Please enter your student ID';
                              }
                              if (_selectedRole == 'teacher' && !value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton(
                            onPressed: authProvider.isLoading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              padding: AppSpacing.verticalMd,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Login', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
