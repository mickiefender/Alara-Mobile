import 'package:flutter/material.dart';

/// Data model for an onboarding page
class OnboardingPage {
  final String title;
  final String description;
  final String svgAsset;
  final Gradient gradient;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.svgAsset,
    required this.gradient,
  });
}

/// Teacher onboarding pages
class TeacherOnboardingPages {
  static const List<OnboardingPage> pages = [
    OnboardingPage(
      title: 'Welcome to Alara',
      description: 'Your complete school management solution. Manage attendance, generate AI questions, track grades, and monitor student progress all in one place.',
      svgAsset: 'assets/svg/Teacher/Welcome.svg',
      gradient: LinearGradient(
        colors: [Color(0xFFAF0303), Color(0xFF000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Take Attendance',
      description: 'Track student attendance with ease. Mark present, absent, or late status for each student. View attendance history and generate reports.',
      svgAsset: 'assets/svg/Teacher/Attendance.svg',
      gradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'AI Question Generator',
      description: 'Generate smart questions using AI. Create quizzes, test papers, and practice questions instantly. Save time and ensure quality.',
      svgAsset: 'assets/svg/Teacher/ai-question-generator.svg',
      gradient: LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Grade Management',
      description: 'Manage grades efficiently. Upload marks, calculate scores, and generate report cards. Support for various assessment types.',
      svgAsset: 'assets/svg/Teacher/grading.svg',
      gradient: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Student Progress Tracking',
      description: 'Monitor student performance over time. Track grades, attendance, and behavior. Identify students who need extra attention.',
      svgAsset: 'assets/svg/Teacher/progress.svg',
      gradient: LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];
}

/// Student onboarding pages
class StudentOnboardingPages {
  static const List<OnboardingPage> pages = [
    OnboardingPage(
      title: 'Welcome to Alara',
      description: 'Your personal school companion. View attendance, check assignments, access timetable, and stay updated with notifications.',
      svgAsset: 'assets/svg/Teacher/Welcome.svg',
      gradient: LinearGradient(
        colors: [Color(0xFFAF0303), Color(0xFF000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'View Attendance',
      description: 'Check your attendance records anytime. See your attendance history, present days, and absences. Stay on top of your attendance.',
      svgAsset: 'assets/svg/student/attendance .svg',
      gradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Assignments & Results',
      description: 'Access all your assignments and submit them online. View your grades and results for all subjects. Track your academic progress.',
      svgAsset: 'assets/svg/student/result.svg',
      gradient: LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Timetable',
      description: 'Never miss a class. View your weekly timetable, lesson schedule, and room assignments. Plan your week effectively.',
      svgAsset: 'assets/svg/student/timetable.svg',
      gradient: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingPage(
      title: 'Notifications',
      description: 'Stay informed about important updates. Get notifications about assignments, announcements, and events. Never miss anything important.',
      svgAsset: 'assets/svg/student/notification.svg',
      gradient: LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];
}
