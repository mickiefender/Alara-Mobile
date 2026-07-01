import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/auth/login_screen.dart';

import 'package:alara/features/teacher/teacher_nav_shell.dart';
import 'package:alara/features/teacher/attendance_screen.dart';
import 'package:alara/features/teacher/ai_questions_screen.dart';
import 'package:alara/features/teacher/teacher_profile_screen.dart';
import 'package:alara/features/teacher/performance_screen.dart';
import 'package:alara/features/teacher/timetable_screen.dart';
import 'package:alara/features/teacher/grade_screen.dart';
import 'package:alara/features/teacher/assignments_materials_screen.dart';

import 'package:alara/features/student/student_nav_shell.dart';
import 'package:alara/features/student/student_profile_screen.dart';
import 'package:alara/features/student/classes_screen.dart';
import 'package:alara/features/student/assignments_screen.dart';
import 'package:alara/features/student/materials_screen.dart';
import 'package:alara/features/student/attendance_screen.dart';
import 'package:alara/features/student/announcements_screen.dart';
import 'package:alara/features/student/fees_screen.dart';
import 'package:alara/features/student/student_ai_assistant_screen.dart';
import 'package:alara/features/student/student_notifications_screen.dart';
import 'package:alara/features/student/tabs/timetable_tab.dart';
import 'package:alara/features/student/tabs/results_tab.dart';

import 'package:alara/features/communication/communication_screen.dart';
import 'package:alara/features/onboarding/onboarding_screen.dart';
import 'package:alara/core/offline/ui/sync_settings_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: AppRoutes.login,

      /// 🔥 IMPORTANT: listens to auth changes
      refreshListenable: authProvider,

      redirect: (context, state) {
        final isBootstrapped = authProvider.isAuthResolved;
        final isLoggedIn = authProvider.isLoggedIn;
        final isOnLogin = state.matchedLocation == AppRoutes.login;

        // -------------------------------
        // 1. WAIT FOR BOOTSTRAP ONLY
        // -------------------------------
        if (!isBootstrapped) {
          return null;
        }

        // -------------------------------
        // 2. NOT LOGGED IN → FORCE LOGIN
        // -------------------------------
        if (!isLoggedIn && !isOnLogin) {
          return AppRoutes.login;
        }

// -------------------------------
        // 3. LOGGED IN → BLOCK LOGIN PAGE
        // -------------------------------
        if (isLoggedIn && isOnLogin) {
          // Check if onboarding is completed for this role
          if (!authProvider.onboardingCompleted) {
            final role = authProvider.isTeacher ? 'teacher' : 'student';
            return '${AppRoutes.onboarding}?role=$role';
          }

          if (authProvider.isTeacher) {
            return AppRoutes.teacherDashboard;
          }

          if (authProvider.isStudent) {
            return AppRoutes.studentDashboard;
          }

          return AppRoutes.login;
        }

        // -------------------------------
        // 4. LOGGED IN BUT ONBOARDING NOT COMPLETED → GO TO ONBOARDING
        // -------------------------------
        if (isLoggedIn && !authProvider.onboardingCompleted) {
          final currentPath = state.matchedLocation;
          // Only redirect if not already on onboarding page
          if (currentPath != AppRoutes.onboarding) {
            final role = authProvider.isTeacher ? 'teacher' : 'student';
            return '${AppRoutes.onboarding}?role=$role';
          }
        }

        return null;
      },

      routes: [
// ---------------- LOGIN ----------------
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LoginScreen(),
          ),
        ),

        // ---------------- ONBOARDING ----------------
        GoRoute(
          path: AppRoutes.onboarding,
          name: 'onboarding',
          pageBuilder: (context, state) {
            final role = state.uri.queryParameters['role'] ?? 'student';
            return NoTransitionPage(
              child: OnboardingScreen(role: role),
            );
          },
        ),

        // ---------------- TEACHER ----------------
        GoRoute(
          path: AppRoutes.teacherDashboard,
          name: 'teacher-dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TeacherNavShell()),
        ),

        GoRoute(
          path: AppRoutes.teacherAttendance,
          name: 'teacher-attendance',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AttendanceScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherAiQuestions,
          name: 'teacher-ai-questions',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AiQuestionsScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherAssignments,
          name: 'teacher-assignments',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AssignmentsMaterialsScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherPerformance,
          name: 'teacher-performance',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: PerformanceScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherProfile,
          name: 'teacher-profile',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TeacherProfileScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherTimetable,
          name: 'teacher-timetable',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TimetableScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherCommunication,
          name: 'teacher-communication',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CommunicationScreen()),
        ),

        GoRoute(
          path: AppRoutes.teacherGrading,
          name: 'teacher-grading',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: GradeScreen()),
        ),

        // ---------------- SYNC ----------------
        GoRoute(
          path: AppRoutes.syncSettings,
          name: 'sync-settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SyncSettingsScreen()),
        ),

        // ---------------- STUDENT ----------------
        GoRoute(
          path: AppRoutes.studentDashboard,
          name: 'student-dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentNavShell()),
),

        GoRoute(
          path: AppRoutes.studentTimetable,
          name: 'student-timetable',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TimetableTab(),
          ),
        ),

        GoRoute(
          path: AppRoutes.studentResults,
          name: 'student-results',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ResultsTab(),
          ),
        ),

        GoRoute(
          path: AppRoutes.studentAssignments,
          name: 'student-assignments',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentAssignmentsScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentMaterials,
          name: 'student-materials',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentMaterialsScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentAttendance,
          name: 'student-attendance',
          pageBuilder: (context, state) =>
const NoTransitionPage(child: StudentAttendanceScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentAnnouncements,
          name: 'student-announcements',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentAnnouncementsScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentFees,
          name: 'student-fees',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentFeesScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentProfile,
          name: 'student-profile',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentProfileScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentClasses,
          name: 'student-classes',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentClassesScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentAiAssistant,
          name: 'student-ai-assistant',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentAiAssistantScreen()),
        ),

        GoRoute(
          path: AppRoutes.studentNotifications,
          name: 'student-notifications',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StudentNotificationsScreen()),
        ),
      ],
    );
  }
}

class AppRoutes {
  static const String login = '/';
  static const String onboarding = '/onboarding';

  static const String teacherDashboard = '/teacher/dashboard';
  static const String teacherAttendance = '/teacher/attendance';
  static const String teacherAiQuestions = '/teacher/ai-questions';
  static const String teacherAssignments = '/teacher/assignments';
  static const String teacherPerformance = '/teacher/performance';
  static const String teacherProfile = '/teacher/profile';
  static const String teacherTimetable = '/teacher/timetable';
  static const String teacherCommunication = '/teacher/communication';
  static const String teacherGrading = '/teacher/grading';

  static const String syncSettings = '/sync-settings';

  static const String studentDashboard = '/student/dashboard';
  static const String studentTimetable = '/student/timetable';
  static const String studentResults = '/student/results';
  static const String studentAssignments = '/student/assignments';
  static const String studentMaterials = '/student/materials';
  static const String studentAttendance = '/student/attendance';
  static const String studentAnnouncements = '/student/announcements';
  static const String studentFees = '/student/fees';
static const String studentProfile = '/student/profile';
  static const String studentClasses = '/student/classes';
  static const String studentAiAssistant = '/student/ai-assistant';
  static const String studentNotifications = '/student/notifications';
}


class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '$title Screen',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This feature will connect to your Django backend',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
