import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/teacher/teacher_dashboard_service.dart';
import 'package:alara/theme.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    try {
      final service = TeacherDashboardService();
      final url = await service.getProfilePictureUrl();
      if (mounted) setState(() => _profilePictureUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: LightModeColors.lightPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: _profilePictureUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: _profilePictureUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Icon(Icons.person, color: Colors.white, size: 40),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.2),
                                    child: Text(
                                      (user?.name ?? 'T').substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.white.withOpacity(0.2),
                                  child: Center(
                                    child: Text(
                                      (user?.name ?? 'T').substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? 'Teacher',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMenuItem(Icons.person_outline, 'Edit Profile', () {}),
                const SizedBox(height: 10),
                _buildMenuItem(Icons.settings_outlined, 'Settings', () {}),
                const SizedBox(height: 10),
                _buildMenuItem(Icons.help_outline, 'Help & Support', () {}),
                const SizedBox(height: 10),
                _buildMenuItem(Icons.info_outline, 'About', () {}),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: LightModeColors.lightError.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout, color: LightModeColors.lightError),
                    ),
                    title: const Text('Logout', style: TextStyle(color: LightModeColors.lightError)),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: LightModeColors.lightOnSurfaceVariant),
                              ),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: LightModeColors.lightError,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await authProvider.logout();
                        if (context.mounted) context.go('/');
                      }
                    },
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: LightModeColors.lightPrimaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: LightModeColors.lightPrimary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: LightModeColors.lightOnSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
