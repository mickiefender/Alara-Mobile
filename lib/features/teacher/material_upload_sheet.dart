import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:alara/services/assignments_materials_service.dart';
import 'package:alara/theme.dart';

/// Bottom sheet allowing a teacher to upload a learning material file
/// with title, description, class/subject association, and optional folder.
class MaterialUploadSheet extends StatefulWidget {
  /// Called after a successful upload with the new document ID.
  /// Returns true if the caller should refresh.
  final Future<bool> Function(int documentId) onUploaded;

  const MaterialUploadSheet({super.key, required this.onUploaded});

  @override
  State<MaterialUploadSheet> createState() => _MaterialUploadSheetState();
}

class _MaterialUploadSheetState extends State<MaterialUploadSheet> {
  final _service = AssignmentsMaterialsService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Picked file
  PlatformFile? _pickedFile;

  // Class/subject pairs loaded from API
  List<ClassSubjectPair> _classSubjectPairs = [];

  // Selected values
  ClassSubjectPair? _selectedPair;
  String _documentType = 'notes';

  bool get _hasValidFile => _pickedFile != null && _pickedFile!.path != null;
  bool get _hasTitle => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pairs = await _service.getTeacherClassSubjects();
      if (mounted) {
        setState(() {
          _classSubjectPairs = pairs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'jpg', 'jpeg', 'png', 'gif', 'zip', 'rar',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (!_hasTitle || !_hasValidFile) return;

    setState(() => _isSubmitting = true);

    final docId = await _service.uploadMaterial(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      filePath: _pickedFile!.path!,
      documentType: _documentType,
      classId: _selectedPair?.classId,
      subjectId: _selectedPair?.subjectId,
    );

    setState(() => _isSubmitting = false);

    if (docId != null && mounted) {
      // Refresh parent
      final success = await widget.onUploaded(docId);
      if (mounted && success) {
        Navigator.of(context).pop();
      } else if (mounted) {
        // If the upload succeeded but the share wasn't triggered yet,
        // still close and let the user share from the list
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please try again.'),
            backgroundColor: LightModeColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 32 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: LightModeColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Upload Learning Material',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: LightModeColors.lightOnSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Material Title *',
                hintText: 'e.g., Chapter 3 - Algebra Notes',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief description of the material',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Document type
            DropdownButtonFormField<String>(
              value: _documentType,
              decoration: const InputDecoration(
                labelText: 'Document Type',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(value: 'notes', child: Text('Notes')),
                DropdownMenuItem(value: 'syllabus', child: Text('Syllabus')),
                DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _documentType = v);
              },
            ),
            const SizedBox(height: 12),

            // Class/Subject picker
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_classSubjectPairs.isNotEmpty)
              DropdownButtonFormField<ClassSubjectPair>(
                value: _selectedPair,
                decoration: const InputDecoration(
                  labelText: 'Class & Subject (optional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _classSubjectPairs.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text('${p.className} - ${p.subjectName}'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedPair = v),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: LightModeColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: LightModeColors.lightOnSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No class assignments found. The material will be uploaded without a class association.',
                        style: TextStyle(fontSize: 12, color: LightModeColors.lightOnSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // File picker
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _hasValidFile
                      ? LightModeColors.accentGreen.withValues(alpha: 0.06)
                      : LightModeColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasValidFile
                        ? LightModeColors.accentGreen.withValues(alpha: 0.3)
                        : LightModeColors.lightOutline.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasValidFile ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                      color: _hasValidFile ? LightModeColors.accentGreen : LightModeColors.lightPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasValidFile ? _pickedFile!.name : 'Tap to select a file *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _hasValidFile ? LightModeColors.accentGreen : LightModeColors.lightOnSurface,
                            ),
                          ),
                          if (_hasValidFile && _pickedFile!.size > 0)
                            Text(
                              _formatFileSize(_pickedFile!.size),
                              style: const TextStyle(
                                fontSize: 11,
                                color: LightModeColors.lightOnSurfaceVariant,
                              ),
                            ),
                          if (!_hasValidFile)
                            const Text(
                              'PDF, DOC, XLS, images, etc. Max 100MB',
                              style: TextStyle(
                                fontSize: 11,
                                color: LightModeColors.lightOnSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_hasValidFile)
                      GestureDetector(
                        onTap: () => setState(() => _pickedFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightError.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 16, color: LightModeColors.lightError),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: (_hasTitle && _hasValidFile && !_isSubmitting) ? _submit : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Upload Material',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
