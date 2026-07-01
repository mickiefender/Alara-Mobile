import 'package:flutter/material.dart';
import 'package:alara/core/models/user.dart';
import 'package:alara/core/services/auth_service.dart';
import 'package:alara/core/services/notification_service.dart';
import 'package:alara/core/services/onboarding_service.dart';

enum AuthStatus {
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  bool _isLoading = false;
  bool _initialized = false;

  AuthStatus _authStatus = AuthStatus.unauthenticated;
  
  // Onboarding state for current user's role
  bool _onboardingCompleted = false;

  // ---------------- GETTERS ----------------

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  bool get isLoggedIn => _authStatus == AuthStatus.authenticated;
  bool get isTeacher => _currentUser?.role == 'teacher';
  bool get isStudent => _currentUser?.role == 'student';
  
  /// Whether onboarding has been completed for the current user's role
  bool get onboardingCompleted => _onboardingCompleted;

  AuthStatus get authStatus => _authStatus;

  /// IMPORTANT: no more "unknown" state that can freeze UI
  bool get isAuthResolved => _initialized;

  // ---------------- INIT / RESTORE ----------------

  Future<void> checkAuthStatus() {
    // prevent duplicate calls
    if (_initialized) return Future.value();

    return _restoreAuth();
  }

Future<void> _restoreAuth() async {
    try {
      final restoredUser = await _authService
          .getCurrentUser()
          .timeout(const Duration(seconds: 5));

      _currentUser = restoredUser;

      _authStatus = restoredUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      
// Check onboarding status only if user was restored
      if (restoredUser != null) {
        _onboardingCompleted = await OnboardingService.instance.isOnboardingCompleted(restoredUser.role);
      }
    } catch (e) {
      debugPrint('Auth restore failed: $e');

      _currentUser = null;
      _authStatus = AuthStatus.unauthenticated;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

// ---------------- LOGIN ----------------

  Future<bool> login(
    String role,
    String identifier,
    String password,
  ) async {
    _setLoading(true);

    try {
      final result = await _authService.login(role, identifier, password);

      _currentUser = User.fromJson(result['user']);
      _authStatus = AuthStatus.authenticated;

      final user = _currentUser;
      if (user != null) {
        await NotificationService.instance.subscribeForUser(user);
        // Check onboarding status for the logged-in user's role
        _onboardingCompleted = await OnboardingService.instance.isOnboardingCompleted(role);
      }

      return true;
    } catch (e) {
      debugPrint('Login failed: $e');
      _authStatus = AuthStatus.unauthenticated;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------- LOGOUT ----------------

  Future<void> logout() async {
    final user = _currentUser;

    if (user != null) {
      try {
        await NotificationService.instance.unsubscribeForUser(user);
      } catch (e) {
        debugPrint('Notification unsubscribe failed: $e');
      }
    }

    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('Logout cleanup failed: $e');
    }

    _currentUser = null;
    _authStatus = AuthStatus.unauthenticated;

    notifyListeners();
  }

  // ---------------- DELETE ACCOUNT ----------------

  Future<void> deleteAccount() async {
    _setLoading(true);

    try {
      final user = _currentUser;

      if (user != null) {
        await NotificationService.instance.unsubscribeForUser(user);
      }

      await _authService.deleteAccount();

      _currentUser = null;
      _authStatus = AuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('Delete account failed: $e');
    } finally {
      _setLoading(false);
    }
  }

// ---------------- HELPER ----------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Mark onboarding as completed for the current user's role
  /// Called from onboarding screen after completing onboarding
  Future<void> completeOnboarding() async {
    if (_currentUser != null) {
      final role = _currentUser!.role;
      await OnboardingService.instance.completeOnboarding(role);
      _onboardingCompleted = true;
      notifyListeners();
    }
  }
}
