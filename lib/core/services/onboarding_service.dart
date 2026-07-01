import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage onboarding state using SharedPreferences
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _teacherOnboardingKey = 'teacher_onboarding_completed';
  static const String _studentOnboardingKey = 'student_onboarding_completed';
  
  static OnboardingService? _instance;
  static SharedPreferences? _prefs;

  OnboardingService._();

  /// Get singleton instance
  static OnboardingService get instance {
    _instance ??= OnboardingService._();
    return _instance!;
  }

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if onboarding has been completed for a specific role
  Future<bool> isOnboardingCompleted(String role) async {
    await init();
    final key = role == 'teacher' ? _teacherOnboardingKey : _studentOnboardingKey;
    return _prefs?.getBool(key) ?? false;
  }

  /// Mark onboarding as completed for a specific role
  Future<void> completeOnboarding(String role) async {
    await init();
    final key = role == 'teacher' ? _teacherOnboardingKey : _studentOnboardingKey;
    await _prefs?.setBool(key, true);
  }

  /// Check if ANY onboarding has been completed (for general app)
  Future<bool> isAnyOnboardingCompleted() async {
    await init();
    final teacherComplete = _prefs?.getBool(_teacherOnboardingKey) ?? false;
    final studentComplete = _prefs?.getBool(_studentOnboardingKey) ?? false;
    return teacherComplete || studentComplete;
  }

  /// Clear onboarding state (for testing/reset)
  Future<void> clearOnboarding() async {
    await init();
    await _prefs?.remove(_teacherOnboardingKey);
    await _prefs?.remove(_studentOnboardingKey);
  }
}
