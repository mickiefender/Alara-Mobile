import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/theme.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    final items = [
      _MoreItem(Icons.assignment_rounded, 'Assignments', 'View & submit assignments', LightModeColors.lightPrimary, '/student/assignments'),
      _MoreItem(Icons.library_books_rounded, 'Materials', 'Access learning resources', LightModeColors.lightTertiary, '/student/materials'),
      _MoreItem(Icons.how_to_reg_rounded, 'Attendance', 'View your attendance record', LightModeColors.accentGreen, '/student/attendance'),
      _MoreItem(Icons.campaign_rounded, 'Announcements', 'School news & updates', LightModeColors.accentPink, '/student/announcements'),
      _MoreItem(Icons.payment_rounded, 'Fees', 'Fee & payment status', LightModeColors.accentOrange, '/student/fees'),
      _MoreItem(Icons.smart_toy_rounded, 'AI Assistant', 'Real-time study support', LightModeColors.accentBlue, '/student/ai-assistant'),
      _MoreItem(Icons.person_outline_rounded, 'Profile', 'View your profile details', Colors.grey, '/student/profile'),
    ];

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('More', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(item.route),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: context.textStyles.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(item.subtitle,
                                  style: context.textStyles.bodySmall?.copyWith(
                                      color: LightModeColors.lightOnSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: LightModeColors.lightOnSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  _MoreItem(this.icon, this.title, this.subtitle, this.color, this.route);
}
