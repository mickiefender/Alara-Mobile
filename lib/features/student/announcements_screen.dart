import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/core/models/announcement.dart';
import 'package:alara/core/models/notice.dart';
import 'package:alara/theme.dart';

/// Unified item type for displaying announcements, notices, and personal notices
class AnnouncementItem {
  final String id;
  final String title;
  final String content;
  final String type; // 'announcement', 'notice', 'personal_notice'
  final String? createdBy;
  final DateTime createdAt;
  final bool isPinned;
  final String priority;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.createdBy,
    required this.createdAt,
    this.isPinned = false,
    this.priority = 'medium',
  });

  factory AnnouncementItem.fromAnnouncement(Announcement a) => AnnouncementItem(
    id: a.id,
    title: a.title,
    content: a.content,
    type: 'announcement',
    createdBy: a.createdByName,
    createdAt: a.publishedDate ?? a.createdAt,
    priority: a.status ?? 'medium',
  );

  factory AnnouncementItem.fromNotice(Notice n) => AnnouncementItem(
    id: n.id,
    title: n.title,
    content: n.content,
    type: 'notice',
    createdBy: n.createdByName,
    createdAt: n.createdAt,
    isPinned: n.isPinned,
    priority: n.priority,
  );

  factory AnnouncementItem.fromPersonalNotice(PersonalNotice n) => AnnouncementItem(
    id: n.id,
    title: n.title,
    content: n.content,
    type: 'personal_notice',
    createdBy: n.createdByName,
    createdAt: n.sentAt,
    priority: 'medium',
  );
}

class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  State<StudentAnnouncementsScreen> createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  final StudentService _service = StudentService();
  List<AnnouncementItem>? _announcements;
  List<AnnouncementItem>? _notices;
  List<AnnouncementItem>? _personalNotices;
  int _selectedFilter = 0; // 0 = All, 1 = Announcements, 2 = Notices, 3 = Personal Notices
  bool _isLoading = true;

  static const _filterOptions = ['All', 'Announcements', 'Notices', 'Personal'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all three types in parallel
      final results = await Future.wait([
        _service.getAnnouncements(),
        _service.getNotices(),
        _service.getPersonalNotices(),
      ]);

      final announcements = results[0] as List<Announcement>;
      final notices = results[1] as List<Notice>;
      final personalNotices = results[2] as List<PersonalNotice>;

      // Convert and group by type
      final announcementItems = announcements.map((a) => AnnouncementItem.fromAnnouncement(a)).toList();
      final noticeItems = notices.map((n) => AnnouncementItem.fromNotice(n)).toList();
      final personalNoticeItems = personalNotices.map((n) => AnnouncementItem.fromPersonalNotice(n)).toList();

      // Sort each group by pinned first, then by date (newest first)
      void sortItems(List<AnnouncementItem> items) {
        items.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
      }

      sortItems(announcementItems);
      sortItems(noticeItems);
      sortItems(personalNoticeItems);

      if (mounted) setState(() {
        _announcements = announcementItems;
        _notices = noticeItems;
        _personalNotices = personalNoticeItems;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<AnnouncementItem> get _allItems {
    return [
      ...(_announcements ?? []),
      ...(_notices ?? []),
      ...(_personalNotices ?? []),
    ];
  }

  List<AnnouncementItem> get _currentItems {
    switch (_selectedFilter) {
      case 1:
        return _announcements ?? [];
      case 2:
        return _notices ?? [];
      case 3:
        return _personalNotices ?? [];
      default:
        return _allItems;
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Announcements', style: TextStyle(color: Colors.white)),
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
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: LightModeColors.lightPrimary))
                : _currentItems.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filterOptions.length, (index) {
            final isSelected = _selectedFilter == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? LightModeColors.lightPrimary 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? LightModeColors.lightPrimary 
                          : LightModeColors.lightOutline,
                    ),
                  ),
                  child: Text(
                    _getFilterLabel(index),
                    style: TextStyle(
                      color: isSelected ? Colors.white : LightModeColors.lightOnSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _getFilterLabel(int index) {
    final count = _getCountForFilter(index);
    if (count == 0) return _filterOptions[index];
    return '${_filterOptions[index]} ($count)';
  }

  int _getCountForFilter(int index) {
    switch (index) {
      case 1:
        return _announcements?.length ?? 0;
      case 2:
        return _notices?.length ?? 0;
      case 3:
        return _personalNotices?.length ?? 0;
      default:
        return _allItems.length;
    }
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.campaign_rounded, size: 80,
            color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text('No announcements yet',
            style: context.textStyles.titleMedium?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Announcements from your school will appear here',
            style: context.textStyles.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.7))),
      ],
    ),
  );

  IconData _iconForType(String type) {
    switch (type) {
      case 'announcement':
        return Icons.campaign_rounded;
      case 'notice':
        return Icons.notifications_active_rounded;
      case 'personal_notice':
        return Icons.mail_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _colorForType(String type, String priority) {
    if (priority == 'urgent') return LightModeColors.accentRed;
    if (priority == 'high') return LightModeColors.accentOrange;
    
    switch (type) {
      case 'announcement':
        return LightModeColors.lightPrimary;
      case 'notice':
        return LightModeColors.accentGreen;
      case 'personal_notice':
        return LightModeColors.accentBlue;
      default:
        return LightModeColors.lightPrimary;
    }
  }

Widget _buildList() {
    if (_selectedFilter == 0) {
      return _buildGroupedList();
    }
    return _buildItemsList(_currentItems);
  }

  Widget _buildGroupedList() {
    final sections = <MapEntry<String, List<AnnouncementItem>>>[];
    
    if ((_announcements ?? []).isNotEmpty) {
      sections.add(MapEntry('Announcements', _announcements!));
    }
    if ((_notices ?? []).isNotEmpty) {
      sections.add(MapEntry('Notices', _notices!));
    }
    if ((_personalNotices ?? []).isNotEmpty) {
      sections.add(MapEntry('Personal Notices', _personalNotices!));
    }

return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.value.length),
        itemBuilder: (context, index) {
          int currentIndex = 0;
          for (final section in sections) {
            if (index == currentIndex) {
              return _buildSectionHeader(section.key, section.value.length);
            }
            currentIndex++;
            if (index < currentIndex + section.value.length) {
              final item = section.value[index - currentIndex];
              return _buildItemCard(item);
            }
            currentIndex += section.value.length;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: context.textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: LightModeColors.lightOnSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LightModeColors.lightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<AnnouncementItem> items) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildItemCard(items[i]),
      ),
    );
  }

  Widget _buildItemCard(AnnouncementItem item) {
    final isRecent = DateTime.now().difference(item.createdAt).inDays < 3;
    final isUrgent = item.priority == 'urgent' || item.priority == 'high';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecent
                ? LightModeColors.lightPrimary.withOpacity(0.2)
                : isUrgent
                    ? LightModeColors.accentRed.withOpacity(0.3)
                    : LightModeColors.lightOutline,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _colorForType(item.type, item.priority).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconForType(item.type),
                        color: _colorForType(item.type, item.priority), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(item.title,
                                  style: context.textStyles.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (item.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.push_pin, size: 14,
                                    color: LightModeColors.accentOrange),
                              ),
                            if (isRecent)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: LightModeColors.accentGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('NEW',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.accentGreen)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy · h:mm a').format(item.createdAt),
                          style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightModeColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.content,
                  style: context.textStyles.bodyMedium?.copyWith(
                      color: LightModeColors.lightOnSurface, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
