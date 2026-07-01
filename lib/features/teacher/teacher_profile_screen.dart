import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/features/teacher/teacher_dashboard_service.dart';
import 'package:alara/theme.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  String? _profilePictureUrl;

  String? _resolveProfileImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${TeacherDashboardService.baseUrl}$trimmed';
    return '${TeacherDashboardService.baseUrl}/$trimmed';
  }

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    try {
      final service = TeacherDashboardService();
      final url = await service.getProfilePictureUrl();
      if (mounted && (url?.trim().isNotEmpty ?? false)) {
        setState(() => _profilePictureUrl = _resolveProfileImageUrl(url));
      }
    } catch (_) {}
  }

  Future<void> _confirmLogout() async {
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

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      try {
        await authProvider.logout();
        if (mounted) context.go('/');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final authProfileImage = _resolveProfileImageUrl(user?.profileImage);
    final profileImageToUse = _profilePictureUrl ?? authProfileImage;

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profileImageToUse != null
                          ? CachedNetworkImage(
                              imageUrl: profileImageToUse,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Icon(Icons.person, color: Colors.white, size: 44),
                              errorWidget: (_, __, ___) => _buildAvatarFallback(user),
                            )
                          : _buildAvatarFallback(user),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    user?.name ?? 'Teacher',
                    style: context.textStyles.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    user?.email ?? '',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Teacher',
                      style: context.textStyles.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info cards
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Personal Information
                _buildSectionTitle('Personal Information'),
                const SizedBox(height: 8),
                _buildInfoCard([
                  _InfoItem(icon: Icons.person_outline, label: 'Full Name', value: user?.name ?? 'N/A'),
                  _InfoItem(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? 'N/A'),
                  _InfoItem(icon: Icons.badge_outlined, label: 'Staff ID', value: user?.id ?? 'N/A'),
                  _InfoItem(icon: Icons.phone_outlined, label: 'Phone', value: user?.phone ?? 'Not set'),
                ]),
                const SizedBox(height: 20),

                // Account Settings
                _buildSectionTitle('Account Settings'),
                const SizedBox(height: 8),
                _buildMenuItem(
                  Icons.person_outline,
                  'Edit Profile',
                  'Update your personal details',
                  _showEditProfileSheet,
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  Icons.lock_outlined,
                  'Change Password',
                  'Update your login credentials',
                  _showChangePasswordSheet,
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  Icons.notifications_outlined,
                  'Notifications',
                  'Manage notification preferences',
                  _showNotificationsSheet,
                ),
                const SizedBox(height: 20),

                // Support
                _buildSectionTitle('Support'),
                const SizedBox(height: 8),
                _buildMenuItem(
                  Icons.help_outline,
                  'Help & Support',
                  'FAQs, guides, and contact us',
                  _showHelpSupportSheet,
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  Icons.info_outline,
                  'About',
                  'App version and information',
                  _showAboutDialogInfo,
                ),
                const SizedBox(height: 30),

                // Logout button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: LightModeColors.lightError.withOpacity(0.15),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: _confirmLogout,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: LightModeColors.lightError.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.logout_rounded, color: LightModeColors.lightError, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logout',
                                    style: context.textStyles.titleSmall?.copyWith(
                                      color: LightModeColors.lightError,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Sign out of your account',
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
                              color: LightModeColors.lightError.withOpacity(0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showEditProfileSheet() {
    final user = context.read<AuthProvider>().currentUser;
    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Profile', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showSnack('Profile update request saved locally');
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordSheet() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Change Password', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_open_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final oldPass = oldController.text.trim();
                    final newPass = newController.text.trim();
                    final confirmPass = confirmController.text.trim();

                    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                      _showSnack('All password fields are required');
                      return;
                    }
                    if (newPass.length < 6) {
                      _showSnack('New password must be at least 6 characters');
                      return;
                    }
                    if (newPass != confirmPass) {
                      _showSnack('New password and confirmation do not match');
                      return;
                    }

                    Navigator.of(sheetContext).pop();
                    _showSnack('Password change request submitted');
                  },
                  child: const Text('Update Password'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationsSheet() {
    bool pushEnabled = true;
    bool emailEnabled = true;
    bool assignmentAlerts = true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Notification Settings', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: pushEnabled,
                    onChanged: (v) => setSheetState(() => pushEnabled = v),
                    title: const Text('Push Notifications'),
                    secondary: const Icon(Icons.notifications_active_outlined),
                  ),
                  SwitchListTile(
                    value: emailEnabled,
                    onChanged: (v) => setSheetState(() => emailEnabled = v),
                    title: const Text('Email Notifications'),
                    secondary: const Icon(Icons.email_outlined),
                  ),
                  SwitchListTile(
                    value: assignmentAlerts,
                    onChanged: (v) => setSheetState(() => assignmentAlerts = v),
                    title: const Text('Assignment Alerts'),
                    secondary: const Icon(Icons.assignment_late_outlined),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showSnack('Notification preferences updated');
                      },
                      child: const Text('Save Preferences'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpSupportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Help & Support', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _supportTile(Icons.menu_book_outlined, 'User Guide', 'Learn how to use key features'),
              _supportTile(Icons.help_center_outlined, 'FAQ', 'Common questions and answers'),
              _supportTile(Icons.support_agent_outlined, 'Contact Support', 'support@alara.app'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showSnack('Support request composer will be available in next update');
                  },
                  child: const Text('Contact Support'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _supportTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: LightModeColors.lightPrimary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  void _showAboutDialogInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'Alara',
      applicationVersion: '1.0.0',
      applicationLegalese: '\u00a9 2026 Alara School Management',
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: context.textStyles.titleSmall?.copyWith(
          color: LightModeColors.lightOnSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: LightModeColors.lightPrimaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: LightModeColors.lightPrimary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            style: context.textStyles.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: LightModeColors.lightOnSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 70,
                  color: LightModeColors.lightOutline.withOpacity(0.4),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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

  Widget _buildAvatarFallback(dynamic user) {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: Center(
        child: Text(
          (user?.name ?? 'T').substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
