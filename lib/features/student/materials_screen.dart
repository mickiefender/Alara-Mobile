import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/theme.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  final StudentService _service = StudentService();
  List<Map<String, dynamic>>? _materials;
  bool _isLoading = true;
  int? _activeMaterialId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final m = await _service.getMaterials();
      if (mounted) setState(() { _materials = m; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Learning Materials', style: TextStyle(color: Colors.white)),
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
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _isLoading ? null : _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LightModeColors.lightPrimary))
          : _materials == null || _materials!.isEmpty
              ? _buildEmpty()
              : _buildMaterialsList(),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.library_books_rounded, size: 80,
            color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text('No materials available',
            style: context.textStyles.titleMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Materials will appear once teachers upload them',
            style: context.textStyles.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.7))),
      ],
    ),
  );

  Widget _buildMaterialsList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _materials!.length,
        itemBuilder: (context, i) {
          final m = _materials![i];
          final title = m['title'] as String? ?? 'Untitled';
          final desc = m['description'] as String? ?? '';
          final subject = m['subject_name'] as String? ?? m['related_subject_name'] as String? ?? '';
          final type = m['document_type'] as String? ?? 'other';
          final date = m['created_at'] as String? ?? '';
          final fileUrl = m['file_url'] as String? ?? '';
          final teacherName = m['uploaded_by_name'] as String? ?? '';

          Color iconColor;
          IconData icon;
          switch (type) {
            case 'lesson_notes':
              icon = Icons.description_rounded;
              iconColor = LightModeColors.accentBlue;
              break;
            case 'handout':
              icon = Icons.picture_as_pdf_rounded;
              iconColor = LightModeColors.lightError;
              break;
            case 'assignment':
              icon = Icons.assignment_rounded;
              iconColor = LightModeColors.accentOrange;
              break;
            case 'reference':
              icon = Icons.menu_book_rounded;
              iconColor = LightModeColors.accentGreen;
              break;
            default:
              // Determine from extension
              final ext = fileUrl.split('.').last.split('?').first.toLowerCase();
              if (ext == 'pdf') {
                icon = Icons.picture_as_pdf_rounded;
                iconColor = LightModeColors.lightError;
              } else if (['doc', 'docx'].contains(ext)) {
                icon = Icons.description_rounded;
                iconColor = LightModeColors.accentBlue;
              } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
                icon = Icons.image_rounded;
                iconColor = LightModeColors.accentGreen;
              } else {
                icon = Icons.insert_drive_file_rounded;
                iconColor = LightModeColors.lightPrimary;
              }
          }

          final materialId = m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}') ?? -1;
          final isBusy = _activeMaterialId == materialId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: context.textStyles.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(desc,
                                style: context.textStyles.bodySmall?.copyWith(
                                    color: LightModeColors.lightOnSurfaceVariant),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (subject.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: LightModeColors.lightPrimaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(subject,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                                          color: LightModeColors.lightPrimary)),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (teacherName.isNotEmpty) ...[
                                Icon(Icons.person_outline, size: 12, color: LightModeColors.lightOnSurfaceVariant),
                                const SizedBox(width: 2),
                                Text(teacherName,
                                    style: TextStyle(fontSize: 10, color: LightModeColors.lightOnSurfaceVariant)),
                                const SizedBox(width: 6),
                              ],
                              if (date.isNotEmpty) ...[
                                Icon(Icons.calendar_today, size: 12, color: LightModeColors.lightOnSurfaceVariant),
                                const SizedBox(width: 2),
                                Text(
                                  DateFormat('MMM dd').format(DateTime.tryParse(date) ?? DateTime.now()),
                                  style: TextStyle(fontSize: 10, color: LightModeColors.lightOnSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: isBusy ? null : () async {
                                  setState(() => _activeMaterialId = materialId);
                                  final ok = await _service.openMaterialInApp(fileUrl);
                                  if (!mounted) return;
                                  setState(() => _activeMaterialId = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? 'Opened material in app' : 'Unable to open material')),
                                  );
                                },
                                icon: const Icon(Icons.visibility_rounded, size: 16),
                                label: const Text('View'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: isBusy ? null : () async {
                                  setState(() => _activeMaterialId = materialId);
                                  final ok = await _service.downloadMaterial(fileUrl);
                                  if (!mounted) return;
                                  setState(() => _activeMaterialId = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? 'Download started' : 'Unable to download material')),
                                  );
                                },
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Download'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
