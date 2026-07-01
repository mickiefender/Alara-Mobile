import 'package:flutter/material.dart';
import 'package:alara/services/assignments_materials_service.dart';
import 'package:alara/theme.dart';

/// Bottom sheet allowing the teacher to share a document with one or more classes.
class MaterialShareSheet extends StatefulWidget {
  final int documentId;
  final String documentTitle;
  final List<int> currentlySharedClassIds;

  const MaterialShareSheet({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.currentlySharedClassIds = const [],
  });

  @override
  State<MaterialShareSheet> createState() => _MaterialShareSheetState();
}

class _MaterialShareSheetState extends State<MaterialShareSheet> {
  final _service = AssignmentsMaterialsService();
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _allClasses = [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.currentlySharedClassIds);
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _service.getAllClasses();
      if (mounted) {
        setState(() {
          _allClasses = classes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _share() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isSubmitting = true);

    final success = await _service.shareMaterialWithClasses(
      documentId: widget.documentId,
      classIds: _selectedIds.toList(),
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared with ${_selectedIds.length} class(es)'),
            backgroundColor: LightModeColors.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share. Please try again.'),
            backgroundColor: LightModeColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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

          Text(
            'Share Material',
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: LightModeColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"${widget.documentTitle}"',
            style: TextStyle(
              fontSize: 13,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Select classes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allClasses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.class_outlined, size: 48,
                                color: LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No classes available',
                              style: TextStyle(color: LightModeColors.lightOnSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _allClasses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cls = _allClasses[index];
                          final id = cls['id'] is int
                              ? cls['id'] as int
                              : int.tryParse(cls['id'].toString()) ?? 0;
                          final name = cls['name'] as String? ?? 'Class #$id';
                          final isSelected = _selectedIds.contains(id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              });
                            },
                            title: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: LightModeColors.lightOnSurface,
                              ),
                            ),
                            subtitle: cls['level_name'] != null
                                ? Text(
                                    cls['level_name'] as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: LightModeColors.lightOnSurfaceVariant,
                                    ),
                                  )
                                : null,
                            activeColor: LightModeColors.lightPrimary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          );
                        },
                      ),
          ),

          // Selected count
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_selectedIds.length} class${_selectedIds.length == 1 ? '' : 'es'} selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightPrimary,
                ),
              ),
            ),

          // Share button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: (_selectedIds.isNotEmpty && !_isSubmitting) ? _share : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share_rounded, size: 18),
              label: Text(
                _isSubmitting
                    ? 'Sharing...'
                    : 'Share with ${_selectedIds.length} class${_selectedIds.length == 1 ? '' : 'es'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
