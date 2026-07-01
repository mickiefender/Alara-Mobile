import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:alara/core/offline/sync/sync_state_provider.dart';
import 'package:alara/core/offline/sync/sync_engine.dart';
import 'package:alara/core/offline/sync/sync_status.dart';
import 'package:alara/core/offline/offline_database.dart';
import 'package:alara/core/offline/models/local_entities.dart';
import 'package:alara/theme.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  List<SyncQueueItem> _failedItems = [];
  bool _isLoadingFailed = false;

  @override
  void initState() {
    super.initState();
    _loadFailedItems();
  }

  Future<void> _loadFailedItems() async {
    setState(() => _isLoadingFailed = true);
    try {
      final items = await SyncEngine.instance.getFailedItems();
      if (mounted) setState(() => _failedItems = items);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFailed = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyncStateProvider>();

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Sync & Offline Data',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              provider.syncNow();
              _loadFailedItems();
            },
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(provider),
          const SizedBox(height: 16),
          _buildQuickActions(provider),
          const SizedBox(height: 24),
          _buildFailedItemsSection(),
        ],
      ),
    );
  }

  Widget _buildStatusCard(SyncStateProvider provider) {
    final state = provider.syncState;
    final (icon, color, label) = _syncMeta(state);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Status',
                      style: const TextStyle(
                        fontSize: 13,
                        color: LightModeColors.lightOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.connectivity == ConnectivityMode.offline)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LightModeColors.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off,
                          size: 14, color: LightModeColors.accentOrange),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: LightModeColors.accentOrange,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LightModeColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done,
                          size: 14, color: LightModeColors.accentGreen),
                      SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: LightModeColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(
                Icons.sync,
                'Pending',
                '${provider.pendingChanges}',
                LightModeColors.accentOrange,
              ),
              const SizedBox(width: 12),
              _infoChip(
                Icons.check_circle_outline,
                'Last Sync',
                provider.lastSyncedLabel,
                LightModeColors.accentGreen,
              ),
              const SizedBox(width: 12),
              _infoChip(
                Icons.error_outline,
                'Failed',
                '${_failedItems.length}',
                _failedItems.isEmpty
                    ? LightModeColors.accentGreen
                    : LightModeColors.lightError,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: LightModeColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(SyncStateProvider provider) {
    final isSyncing = provider.syncState == SyncUiState.syncing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.sync,
                  label: 'Sync Now',
                  color: LightModeColors.lightPrimary,
                  isLoading: isSyncing,
                  onTap: isSyncing ? null : () => provider.syncNow(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.cleaning_services,
                  label: 'Clear Old',
                  color: LightModeColors.accentOrange,
                  onTap: () async {
                    await SyncEngine.instance.clearSyncedHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Old sync history cleared')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.refresh,
                  label: 'Retry All',
                  color: _failedItems.isEmpty
                      ? LightModeColors.lightOnSurfaceVariant
                      : LightModeColors.accentGreen,
                  onTap: _failedItems.isEmpty
                      ? null
                      : () async {
                          for (final item in _failedItems) {
                            await SyncEngine.instance.retryItem(item.id);
                          }
                          await SyncEngine.instance.triggerSyncNow();
                          _loadFailedItems();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Retrying all failed items...')),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailedItemsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Failed Items',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (_failedItems.isNotEmpty)
                TextButton(
                  onPressed: _loadFailedItems,
                  child: const Text('Refresh', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingFailed)
            const Center(child: CircularProgressIndicator())
          else if (_failedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No failed sync items',
                  style: TextStyle(
                    color: LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_failedItems.length, (index) {
              final item = _failedItems[index];
              final dateStr = DateFormat('MMM d, HH:mm').format(item.updatedAt);
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < _failedItems.length - 1 ? 8 : 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LightModeColors.lightError.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: LightModeColors.lightError.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.entityType} #${item.entityId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.method} ${item.endpoint}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: LightModeColors
                                        .lightOnSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (item.lastError != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.lastError!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: LightModeColors.lightError,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Retry ${item.retryCount}/${item.maxRetries}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 28,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await SyncEngine.instance.retryItem(item.id);
                                await SyncEngine.instance.triggerSyncNow();
                                _loadFailedItems();
                              },
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Retry',
                                  style: TextStyle(fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 28,
                            child: TextButton.icon(
                              onPressed: () async {
                                await SyncEngine.instance.removeItem(item.id);
                                _loadFailedItems();
                              },
                              icon: const Icon(Icons.delete_outline, size: 14),
                              label: const Text('Remove',
                                  style: TextStyle(fontSize: 10)),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                foregroundColor: LightModeColors.lightError,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  (IconData, Color, String) _syncMeta(SyncUiState state) {
    switch (state) {
      case SyncUiState.synced:
        return (Icons.cloud_done, LightModeColors.accentGreen, 'All Synced');
      case SyncUiState.syncing:
        return (Icons.sync, LightModeColors.accentBlue, 'Syncing...');
      case SyncUiState.pendingSync:
        return (Icons.schedule, LightModeColors.accentOrange,
            'Pending Changes');
      case SyncUiState.failedSync:
        return (Icons.error_outline, LightModeColors.lightError,
            'Sync Failed');
      case SyncUiState.localStorage:
        return (Icons.storage, Colors.grey, 'Local Storage');
    }
  }
}
