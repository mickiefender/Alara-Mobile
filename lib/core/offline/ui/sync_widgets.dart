import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alara/core/offline/sync/sync_state_provider.dart';
import 'package:alara/core/offline/sync/sync_status.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyncStateProvider>();
    if (!provider.showOfflineBanner) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade700,
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Changes will be saved locally and synced later.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SyncStateProvider>();
    final state = provider.syncState;

    final (label, color, icon) = _meta(state);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Status: $label\nLast synced: ${provider.lastSyncedLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Pending: ${provider.pendingChanges}'),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: provider.syncNow,
                  child: const Text('Sync Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, IconData) _meta(SyncUiState state) {
    switch (state) {
      case SyncUiState.synced:
        return ('Synced', Colors.green, Icons.cloud_done);
      case SyncUiState.syncing:
        return ('Syncing', Colors.blue, Icons.sync);
      case SyncUiState.pendingSync:
        return ('Pending Sync', Colors.orange, Icons.schedule);
      case SyncUiState.failedSync:
        return ('Failed Sync', Colors.red, Icons.error_outline);
      case SyncUiState.localStorage:
        return ('Local Storage', Colors.grey, Icons.storage);
    }
  }
}
