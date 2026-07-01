import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alara/core/providers/auth_provider.dart';
import 'package:alara/services/assignments_materials_service.dart';
import 'package:alara/theme.dart';
import 'package:alara/features/teacher/material_upload_sheet.dart';
import 'package:alara/features/teacher/material_share_sheet.dart';
import 'package:alara/nav.dart';

// =============================================================================
// ASSIGNMENTS & MATERIALS SCREEN
// =============================================================================

class AssignmentsMaterialsScreen extends StatefulWidget {
  const AssignmentsMaterialsScreen({super.key});

  @override
  State<AssignmentsMaterialsScreen> createState() =>
      _AssignmentsMaterialsScreenState();
}

class _AssignmentsMaterialsScreenState
    extends State<AssignmentsMaterialsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = AssignmentsMaterialsService();

  // Data
  List<AssignmentListItem> _assignments = [];
  List<MaterialListItem> _materials = [];
  AssignmentsStats _assignmentStats = AssignmentsStats();
  MaterialsStats _materialStats = MaterialsStats();

  // State
  bool _isLoading = true;
  String? _error;

  // Filters
  String _assignmentFilter = 'all'; // all | active | overdue | graded
  String _materialFilter = 'all'; // all | recent | subject
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final assignments = await _service.getAssignments();
      final materials = await _service.getMaterials();
      final assignmentStats = await _service.getAssignmentsStats();
      final materialStats = await _service.getMaterialsStats();

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _materials = materials;
          _assignmentStats = assignmentStats;
          _materialStats = materialStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FILTERED LISTS
  // ---------------------------------------------------------------------------

  List<AssignmentListItem> get _filteredAssignments {
    var list = _assignments;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.subjectName.toLowerCase().contains(q) ||
          a.className.toLowerCase().contains(q)).toList();
    }
    switch (_assignmentFilter) {
      case 'active':
        return list.where((a) => !a.isOverdue).toList();
      case 'overdue':
        return list.where((a) => a.isOverdue).toList();
      case 'graded':
        return list.where((a) => a.gradedCount > 0).toList();
      default:
        return list;
    }
  }

  List<MaterialListItem> get _filteredMaterials {
    var list = _materials;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) =>
          m.title.toLowerCase().contains(q) ||
          (m.subjectName?.toLowerCase().contains(q) ?? false) ||
          (m.uploadedByName?.toLowerCase().contains(q) ?? false)).toList();
    }
    switch (_materialFilter) {
      case 'recent':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list.take(10).toList();
      default:
        return list;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final topInset = MediaQuery.of(context).padding.top;
    final topBarHeight = topInset + 186;

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: LightModeColors.lightPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Gradient Header ──────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TopBarDelegate(
                minHeight: topBarHeight,
                maxHeight: topBarHeight,
                child: _buildHeader(user),
              ),
            ),
            // ── Tab Bar ──────────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                minHeight: 56,
                maxHeight: 56,
                tabController: _tabController,
                assignmentCount: _assignments.length,
                materialCount: _materials.length,
              ),
            ),
            // ── Search ───────────────────────────────────────────────────
            if (_searchController.text.isNotEmpty || _tabController.index == 1)
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),
            // ── Content ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()))
                  : _error != null
                      ? SliverFillRemaining(child: _buildErrorState())
                      : SliverList(
                          delegate: SliverChildListDelegate([
                            if (_tabController.index == 0)
                              _buildAssignmentContent()
                            else
                              _buildMaterialContent(),
                          ]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPUTED STATS
  // ===========================================================================

  int get _computedActiveCount =>
      _assignments.where((a) => !a.isOverdue).length;

  int get _computedOverdueCount =>
      _assignments.where((a) => a.isOverdue).length;

  int get _computedToGradeCount =>
      _assignments.fold(0, (sum, a) => sum + (a.submissionCount - a.gradedCount));

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader(user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LightModeColors.lightPrimary,
            LightModeColors.lightSecondary,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: _handleBackNavigation,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assignments & Materials',
                          style: context.textStyles.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage and share learning resources',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Create button
                  GestureDetector(
                    onTap: () => _showCreateChoice(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row — computed from actual assignments list
              Row(
                children: [
                  Expanded(
                    child: _HeaderStat(
                      icon: Icons.assignment_rounded,
                      value: '$_computedActiveCount',
                      label: 'Active',
                      color: const Color(0xFFFCD34D),
                    ),
                  ),
                  Expanded(
                    child: _HeaderStat(
                      icon: Icons.schedule_rounded,
                      value: '$_computedOverdueCount',
                      label: 'Overdue',
                      color: const Color(0xFFFCA5A5),
                    ),
                  ),
                  Expanded(
                    child: _HeaderStat(
                      icon: Icons.library_books_rounded,
                      value: '${_materialStats.total}',
                      label: 'Materials',
                      color: const Color(0xFFA7F3D0),
                    ),
                  ),
                  Expanded(
                    child: _HeaderStat(
                      icon: Icons.download_done_rounded,
                      value: '$_computedToGradeCount',
                      label: 'To Grade',
                      color: const Color(0xFFC4B5FD),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB BAR DELEGATE
  // ===========================================================================

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      color: LightModeColors.lightBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: LightModeColors.lightOutline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: LightModeColors.lightOnSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: _tabController.index == 0
                      ? 'Search assignments...'
                      : 'Search materials...',
                  hintStyle: TextStyle(
                    color: LightModeColors.lightOnSurfaceVariant
                        .withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: LightModeColors.lightOnSurface,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ASSIGNMENT CONTENT
  // ===========================================================================

  List<AssignmentListItem> get _activeAssignments =>
      _assignments.where((a) => !a.isOverdue).toList();

  List<AssignmentListItem> get _overdueAssignments =>
      _assignments.where((a) => a.isOverdue).toList();

  Widget _buildAssignmentContent() {
    final filtered = _filteredAssignments;
    final hasSearch = _searchQuery.isNotEmpty;

    if (filtered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignmentFilterChips(),
          const SizedBox(height: 16),
          _buildEmptyState(
            icon: Icons.assignment_outlined,
            message: _searchQuery.isNotEmpty
                ? 'No assignments match your search'
                : 'No assignments yet',
            subtitle: 'Create your first assignment to get started',
          ),
        ],
      );
    }

    // When filtering by a specific type, just show a flat list
    if (_assignmentFilter != 'all') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignmentFilterChips(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} ${filtered.length == 1 ? 'Assignment' : 'Assignments'}',
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightOnSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...filtered.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: a,
                  onTap: () => _showAssignmentDetail(a),
                ),
              )),
        ],
      );
    }

    // Default view: grouped by Active and Overdue
    final active = hasSearch
        ? filtered.where((a) => !a.isOverdue).toList()
        : _activeAssignments;
    final overdue = hasSearch
        ? filtered.where((a) => a.isOverdue).toList()
        : _overdueAssignments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAssignmentFilterChips(),
        const SizedBox(height: 16),

        // ── Active Section ──────────────────────────────────────────────
        if (active.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCD34D),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Active (${active.length})',
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightOnSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...active.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: a,
                  onTap: () => _showAssignmentDetail(a),
                ),
              )),
          const SizedBox(height: 20),
        ],

        // ── Overdue Section ─────────────────────────────────────────────
        if (overdue.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCA5A5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Overdue (${overdue.length})',
                style: context.textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.lightError,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...overdue.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssignmentCard(
                  assignment: a,
                  onTap: () => _showAssignmentDetail(a),
                ),
              )),
        ],

        if (active.isEmpty && overdue.isNotEmpty && hasSearch)
          _buildEmptyState(
            icon: Icons.assignment_outlined,
            message: 'No assignments match your search',
            subtitle: '',
          ),
      ],
    );
  }

  String get _assignmentFilterLabel {
    switch (_assignmentFilter) {
      case 'active':
        return 'Active';
      case 'overdue':
        return 'Overdue';
      case 'graded':
        return 'Graded';
      default:
        return 'All';
    }
  }

  Widget _buildAssignmentFilterChips() {
    final filters = [
      ('all', 'All', _assignments.length),
      ('active', 'Active', _assignmentStats.active),
      ('overdue', 'Overdue', _assignmentStats.overdue),
      ('graded', 'Graded', _assignmentStats.pendingGrading),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _assignmentFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _assignmentFilter = f.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? LightModeColors.lightPrimary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? LightModeColors.lightPrimary
                        : LightModeColors.lightOutline.withValues(alpha: 0.4),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: LightModeColors.lightPrimary
                                .withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '${f.$2} (${f.$3})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAssignmentFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              'Sort by',
              style: context.textStyles.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _FilterOption(
              label: 'All Assignments',
              subtitle: 'Show everything',
              icon: Icons.list_rounded,
              isSelected: _assignmentFilter == 'all',
              onTap: () {
                setState(() => _assignmentFilter = 'all');
                Navigator.pop(ctx);
              },
            ),
            _FilterOption(
              label: 'Active',
              subtitle: 'Not yet due',
              icon: Icons.schedule_rounded,
              isSelected: _assignmentFilter == 'active',
              onTap: () {
                setState(() => _assignmentFilter = 'active');
                Navigator.pop(ctx);
              },
            ),
            _FilterOption(
              label: 'Overdue',
              subtitle: 'Past due date',
              icon: Icons.warning_amber_rounded,
              isSelected: _assignmentFilter == 'overdue',
              onTap: () {
                setState(() => _assignmentFilter = 'overdue');
                Navigator.pop(ctx);
              },
            ),
            _FilterOption(
              label: 'Needs Grading',
              subtitle: 'Submitted but not graded',
              icon: Icons.rate_review_rounded,
              isSelected: _assignmentFilter == 'graded',
              onTap: () {
                setState(() => _assignmentFilter = 'graded');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MATERIAL CONTENT
  // ===========================================================================

  Widget _buildMaterialContent() {
    final filtered = _filteredMaterials;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        _buildMaterialFilterChips(),
        const SizedBox(height: 16),

        // Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${filtered.length} ${filtered.length == 1 ? 'Material' : 'Materials'}',
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: LightModeColors.lightOnSurface,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: LightModeColors.lightPrimaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 12,
                    color: LightModeColors.lightPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_materialStats.recentUploads} new',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.lightPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          _buildEmptyState(
            icon: Icons.library_books_outlined,
            message: _searchQuery.isNotEmpty
                ? 'No materials match your search'
                : 'No materials yet',
            subtitle: 'Upload learning materials for your classes',
          )
        else
          ...filtered.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MaterialCard(
                  material: m,
                  onShare: () => _showShareSheet(m.id, m.title),
                  onView: () => _openMaterial(m),
                  onDownload: () => _openMaterial(m, download: true),
                ),
              )),

        if (_materials.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Showing ${filtered.length} of ${_materials.length} materials',
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMaterialFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MaterialFilterChip(
            label: 'All',
            count: _materials.length,
            isSelected: _materialFilter == 'all',
            onTap: () => setState(() => _materialFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _MaterialFilterChip(
            label: 'Recent',
            count: _materialStats.recentUploads,
            isSelected: _materialFilter == 'recent',
            onTap: () => setState(() => _materialFilter = 'recent'),
          ),
          const SizedBox(width: 8),
          ...['PDF', 'DOC', 'Notes'].map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MaterialFilterChip(
                  label: t,
                  count: _materials
                      .where((m) => m.fileExtension == t || m.documentType == t.toLowerCase())
                      .length,
                  isSelected: false,
                  onTap: () {},
                ),
              )),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: LightModeColors.lightOutline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: context.textStyles.titleSmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load data',
            style: context.textStyles.titleMedium?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to retry',
            style: context.textStyles.bodySmall?.copyWith(
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAIL SHEETS
  // ===========================================================================

  void _showAssignmentDetail(AssignmentListItem assignment) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignmentDetailSheet(
        assignment: assignment,
        dateFormat: dateFormat,
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDeleteAssignment(assignment);
        },
        onEdit: () {
          Navigator.pop(ctx);
          _showSnackBar('Edit coming soon');
        },
      ),
    );
  }

  void _confirmDeleteAssignment(AssignmentListItem assignment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Assignment'),
        content: Text(
            'Are you sure you want to delete "${assignment.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: LightModeColors.lightOnSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await _service.deleteAssignment(assignment.id);
              if (success) {
                _loadData();
                _showSnackBar('Assignment deleted');
              } else {
                _showSnackBar('Failed to delete assignment', isError: true);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: LightModeColors.lightError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: LightModeColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create New',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: LightModeColors.lightOnSurface,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: LightModeColors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_rounded, color: LightModeColors.accentOrange),
              ),
              title: const Text('Assignment', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a new assignment with due date'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateBottomSheet();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.library_books_rounded, color: LightModeColors.lightPrimary),
              ),
              title: const Text('Learning Material', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Upload a file (PDF, DOC, etc.)'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _showUploadMaterialSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadMaterialSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MaterialUploadSheet(
        onUploaded: (docId) async {
          // Wait for data to reload completely before showing share sheet
          await _loadData();
          if (mounted) {
            // Small delay to ensure state is settled
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              _showShareSheetAfterUpload(docId);
            }
          }
          return true;
        },
      ),
    );
  }

  void _showShareSheetAfterUpload(int docId) {
    // Find the title from the materials list or use a default
    final material = _materials.where((m) => m.id == docId).firstOrNull;
    final title = material?.title ?? 'New Material';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MaterialShareSheet(
        documentId: docId,
        documentTitle: title,
      ),
    ).then((result) {
      if (result == true && mounted) {
        _showSnackBar('Material uploaded and sent to students!');
      }
    });
  }

  void _showShareSheet(int docId, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MaterialShareSheet(
        documentId: docId,
        documentTitle: title,
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
        _showSnackBar('Material sent to students!');
      }
    });
  }

  Future<void> _openMaterial(
    MaterialListItem material, {
    bool download = false,
  }) async {
    final rawUrl = material.fileUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      _showSnackBar('No file available for this material', isError: true);
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      _showSnackBar('Invalid file link', isError: true);
      return;
    }

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      _showSnackBar('Cannot open this material right now', isError: true);
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      _showSnackBar('Failed to open material', isError: true);
      return;
    }

    if (download) {
      _showSnackBar('Opening download...');
    }
  }

  void _handleBackNavigation() {
    context.go(AppRoutes.teacherDashboard);
  }

  void _showCreateBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateAssignmentSheet(
        onCreate: (title, description, classId, subjectId, dueDate) async {
          Navigator.pop(ctx);
          final success = await _service.createAssignment(
            title: title,
            description: description,
            classId: classId,
            subjectId: subjectId,
            dueDate: dueDate,
          );
          if (success) {
            _loadData();
            _showSnackBar('Assignment created!');
          } else {
            _showSnackBar('Failed to create assignment', isError: true);
          }
          return success;
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? LightModeColors.lightError
            : LightModeColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }
}

// =============================================================================
// DELEGATE
// =============================================================================

class _TopBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _TopBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TopBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final TabController tabController;
  final int assignmentCount;
  final int materialCount;

  _TabBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.tabController,
    required this.assignmentCount,
    required this.materialCount,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: LightModeColors.lightBackground,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(
            color: LightModeColors.lightPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          labelColor: Colors.white,
          unselectedLabelColor: LightModeColors.lightOnSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.all(4),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Assignments'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tabController.index == 0
                          ? Colors.white.withValues(alpha: 0.2)
                          : LightModeColors.lightOutline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$assignmentCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tabController.index == 0
                            ? Colors.white
                            : LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Materials'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tabController.index == 1
                          ? Colors.white.withValues(alpha: 0.2)
                          : LightModeColors.lightOutline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$materialCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tabController.index == 1
                            ? Colors.white
                            : LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabController != oldDelegate.tabController ||
        assignmentCount != oldDelegate.assignmentCount ||
        materialCount != oldDelegate.materialCount;
  }
}

// =============================================================================
// HEADER STAT
// =============================================================================

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
    );
  }
}

// =============================================================================
// FILTER OPTION
// =============================================================================

class _FilterOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? LightModeColors.lightPrimaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? LightModeColors.lightPrimary.withValues(alpha: 0.1)
                        : LightModeColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? LightModeColors.lightPrimary
                        : LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? LightModeColors.lightPrimary
                              : LightModeColors.lightOnSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: LightModeColors.lightPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MATERIAL FILTER CHIP
// =============================================================================

class _MaterialFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _MaterialFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? LightModeColors.lightPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? LightModeColors.lightPrimary
                : LightModeColors.lightOutline.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : LightModeColors.lightOnSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ASSIGNMENT CARD
// =============================================================================

class _AssignmentCard extends StatelessWidget {
  final AssignmentListItem assignment;
  final VoidCallback onTap;

  const _AssignmentCard({
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = assignment.isOverdue;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isOverdue) {
      statusColor = LightModeColors.lightError;
      statusLabel = 'Overdue';
      statusIcon = Icons.warning_amber_rounded;
    } else if (assignment.hasSubmissions) {
      statusColor = LightModeColors.accentGreen;
      statusLabel = '${assignment.submissionCount} submitted';
      statusIcon = Icons.check_circle_outline_rounded;
    } else {
      statusColor = LightModeColors.accentOrange;
      statusLabel = 'Active';
      statusIcon = Icons.schedule_rounded;
    }

    final daysUntilDue = assignment.timeRemaining.inDays;
    final dueLabel = isOverdue
        ? '${daysUntilDue.abs() + 1}d overdue'
        : daysUntilDue == 0
            ? 'Due today'
            : daysUntilDue == 1
                ? 'Due tomorrow'
                : '$daysUntilDue days left';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? LightModeColors.lightError.withValues(alpha: 0.15)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: subject badge + status
            Row(
              children: [
                // Subject indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _subjectColor(assignment.subjectName),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  assignment.subjectName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _subjectColor(assignment.subjectName),
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              assignment.title,
              style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: LightModeColors.lightOnSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (assignment.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                assignment.description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            // Bottom row: class, due date, stats
            Row(
              children: [
                // Class + due date
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.class_rounded,
                              size: 11,
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              assignment.className,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: LightModeColors.lightOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? LightModeColors.lightError.withValues(alpha: 0.08)
                              : LightModeColors.accentGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: isOverdue
                                  ? LightModeColors.lightError
                                  : LightModeColors.accentGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isOverdue
                                    ? LightModeColors.lightError
                                    : LightModeColors.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Submission count
                if (assignment.hasSubmissions)
                  Text(
                    '${assignment.gradedCount}/${assignment.submissionCount} graded',
                    style: const TextStyle(
                      fontSize: 10,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _subjectColor(String subjectName) {
    final colors = [
      LightModeColors.accentBlue,
      LightModeColors.accentGreen,
      LightModeColors.accentOrange,
      LightModeColors.accentPink,
      LightModeColors.lightPrimary,
      LightModeColors.lightTertiary,
    ];
    final index = subjectName.hashCode % colors.length;
    return colors[index];
  }
}

// =============================================================================
// MATERIAL CARD
// =============================================================================

class _MaterialCard extends StatelessWidget {
  final MaterialListItem material;
  final VoidCallback? onShare;
  final VoidCallback? onView;
  final VoidCallback? onDownload;

  const _MaterialCard({
    required this.material,
    this.onShare,
    this.onView,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // File type icon - tappable to open/view
          GestureDetector(
            onTap: onView,
            child: _buildFileIcon(),
          ),
          const SizedBox(width: 14),
          // Info - tappable to open/view
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: context.textStyles.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.lightOnSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (material.subjectName != null) ...[
                        Text(
                          material.subjectName!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: LightModeColors.lightPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: LightModeColors.lightOutline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        dateFormat.format(material.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (material.uploadedByName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'by ${material.uploadedByName}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Action buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (material.fileSize != null)
                Text(
                  material.fileSize!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Share/Send button
                  if (onShare != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: onShare,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: LightModeColors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: LightModeColors.accentGreen,
                          ),
                        ),
                      ),
                    ),
                  // Download button
                  if (onDownload != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: onDownload,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: LightModeColors.accentBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            size: 16,
                            color: LightModeColors.accentBlue,
                          ),
                        ),
                      ),
                    ),
                  // Open/View button
                  GestureDetector(
                    onTap: onView,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: LightModeColors.lightPrimaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: LightModeColors.lightPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon() {
    final iconType = material.iconType;
    Color bgColor;
    IconData icon;

    switch (iconType) {
      case IconType.pdf:
        bgColor = LightModeColors.lightError.withValues(alpha: 0.1);
        icon = Icons.picture_as_pdf_rounded;
        break;
      case IconType.doc:
        bgColor = LightModeColors.accentBlue.withValues(alpha: 0.1);
        icon = Icons.description_rounded;
        break;
      case IconType.sheet:
        bgColor = LightModeColors.accentGreen.withValues(alpha: 0.1);
        icon = Icons.table_chart_rounded;
        break;
      case IconType.presentation:
        bgColor = LightModeColors.accentOrange.withValues(alpha: 0.1);
        icon = Icons.slideshow_rounded;
        break;
      case IconType.image:
        bgColor = LightModeColors.accentPink.withValues(alpha: 0.1);
        icon = Icons.image_rounded;
        break;
      case IconType.archive:
        bgColor = LightModeColors.lightPrimaryContainer;
        icon = Icons.folder_zip_rounded;
        break;
      case IconType.text:
        bgColor = LightModeColors.lightSurfaceVariant;
        icon = Icons.article_rounded;
        break;
      default:
        bgColor = LightModeColors.lightSurfaceVariant;
        icon = Icons.insert_drive_file_rounded;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: iconType == IconType.pdf
          ? LightModeColors.lightError
          : LightModeColors.lightOnSurfaceVariant),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }
}

// =============================================================================
// ASSIGNMENT DETAIL BOTTOM SHEET
// =============================================================================

class _AssignmentDetailSheet extends StatelessWidget {
  final AssignmentListItem assignment;
  final DateFormat dateFormat;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AssignmentDetailSheet({
    required this.assignment,
    required this.dateFormat,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: LightModeColors.lightOutline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject + class badges
                  Row(
                    children: [
                      _DetailBadge(
                        label: assignment.subjectName,
                        color: LightModeColors.lightPrimary,
                      ),
                      const SizedBox(width: 8),
                      _DetailBadge(
                        label: assignment.className,
                        color: LightModeColors.accentBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(
                    assignment.title,
                    style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: LightModeColors.lightOnSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Due date
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: LightModeColors.lightOnSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Due: ${dateFormat.format(assignment.dueDate)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (assignment.isOverdue) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: LightModeColors.lightError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 12, color: LightModeColors.lightError),
                          SizedBox(width: 4),
                          Text(
                            'Overdue - past due date',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.lightError,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (assignment.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Description',
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: LightModeColors.lightOnSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      assignment.description,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Stats
                  Text(
                    'Submissions',
                    style: context.textStyles.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.lightOnSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DetailStatBox(
                        icon: Icons.upload_file_rounded,
                        value: '${assignment.submissionCount}',
                        label: 'Submitted',
                        color: LightModeColors.accentBlue,
                      ),
                      const SizedBox(width: 10),
                      _DetailStatBox(
                        icon: Icons.check_circle_rounded,
                        value: '${assignment.gradedCount}',
                        label: 'Graded',
                        color: LightModeColors.accentGreen,
                      ),
                      const SizedBox(width: 10),
                      _DetailStatBox(
                        icon: Icons.pending_rounded,
                        value: '${assignment.submissionCount - assignment.gradedCount}',
                        label: 'Pending',
                        color: LightModeColors.accentOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LightModeColors.lightError,
                              side: const BorderSide(
                                  color: LightModeColors.lightError),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DetailStatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _DetailStatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CREATE ASSIGNMENT BOTTOM SHEET
// =============================================================================

class _CreateAssignmentSheet extends StatefulWidget {
  final Future<bool> Function(
    String title,
    String description,
    int classId,
    int subjectId,
    DateTime dueDate,
  ) onCreate;

  const _CreateAssignmentSheet({required this.onCreate});

  @override
  State<_CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<_CreateAssignmentSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  final _service = AssignmentsMaterialsService();
  List<ClassSubjectPair> _classSubjects = [];
  ClassSubjectPair? _selectedPair;
  bool _isLoadingPairs = true;

  @override
  void initState() {
    super.initState();
    _loadClassSubjects();
  }

  Future<void> _loadClassSubjects() async {
    try {
      final pairs = await _service.getTeacherClassSubjects();
      if (mounted) {
        setState(() {
          _classSubjects = pairs;
          _isLoadingPairs = false;
          if (pairs.isNotEmpty) _selectedPair = pairs.first;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPairs = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _showClassPicker() {
    final grouped = <String, List<ClassSubjectPair>>{};
    for (final p in _classSubjects) {
      grouped.putIfAbsent(p.className, () => []).add(p);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: LightModeColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Class & Subject',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (grouped.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No classes assigned to you')),
              )
            else
              ...grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, top: 8),
                      child: Text(
                        entry.key,
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: LightModeColors.lightPrimary,
                        ),
                      ),
                    ),
                    ...entry.value.map((pair) {
                      final isSelected = _selectedPair?.classId == pair.classId &&
                          _selectedPair?.subjectId == pair.subjectId;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? LightModeColors.lightPrimary.withValues(alpha: 0.1)
                                : LightModeColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.book_rounded,
                            size: 18,
                            color: isSelected
                                ? LightModeColors.lightPrimary
                                : LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                        title: Text(pair.subjectName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(pair.className, style: const TextStyle(fontSize: 12)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () {
                          setState(() => _selectedPair = pair);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final canSubmit = _titleController.text.trim().isNotEmpty &&
        _selectedPair != null &&
        !_isSubmitting;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'New Assignment',
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: LightModeColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Assignment Title *',
              hintText: 'e.g., Algebra Homework - Chapter 3',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Instructions, expectations...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          // Class & Subject picker
          if (_isLoadingPairs)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Loading your classes...', style: TextStyle(fontSize: 13, color: LightModeColors.lightOnSurfaceVariant)),
                ],
              ),
            )
          else
            InkWell(
              onTap: _showClassPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: LightModeColors.lightOutline.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.class_rounded,
                        size: 18, color: LightModeColors.lightPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedPair != null
                            ? '${_selectedPair!.subjectName} — ${_selectedPair!.className}'
                            : 'Select Class & Subject *',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedPair != null
                              ? LightModeColors.lightOnSurface
                              : LightModeColors.lightOnSurfaceVariant,
                          fontWeight: _selectedPair != null ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: LightModeColors.lightOnSurfaceVariant),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Due date
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: LightModeColors.lightOutline.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 18, color: LightModeColors.lightPrimary),
                  const SizedBox(width: 10),
                  Text(
                    'Due: ${dateFormat.format(_dueDate)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: LightModeColors.lightOnSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: canSubmit
                  ? () async {
                      setState(() => _isSubmitting = true);
                      await widget.onCreate(
                        _titleController.text.trim(),
                        _descController.text.trim(),
                        _selectedPair!.classId,
                        _selectedPair!.subjectId,
                        _dueDate,
                      );
                    }
                  : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Assignment',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
