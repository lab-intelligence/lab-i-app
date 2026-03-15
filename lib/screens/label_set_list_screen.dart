import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/label_set.dart';
import '../providers/label_set_provider.dart';

class LabelSetListScreen extends ConsumerWidget {
  const LabelSetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelSetsAsync = ref.watch(labelSetListProvider);
    final activeId = ref.watch(activeLabelSetIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Label Sets'),
      ),
      body: labelSetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (labelSets) {
          if (labelSets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No label sets yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: labelSets.length,
            itemBuilder: (context, index) {
              final ls = labelSets[index];
              final isActive = ls.id == activeId;

              return _LabelSetTile(
                labelSet: ls,
                isActive: isActive,
                onTap: () => context.push('/label-sets/${ls.id}'),
                onSetActive: () {
                  ref.read(activeLabelSetIdProvider.notifier).state =
                      isActive ? null : ls.id;
                },
                onDelete: () => _confirmDelete(context, ref, ls),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/label-sets/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LabelSet labelSet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Label Set?'),
        content: Text('Delete "${labelSet.name}" and its ${labelSet.labels.length} labels?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear active selection if deleting the active set
      final activeId = ref.read(activeLabelSetIdProvider);
      if (activeId == labelSet.id) {
        ref.read(activeLabelSetIdProvider.notifier).state = null;
      }
      await ref.read(labelSetListProvider.notifier).deleteLabelSet(labelSet.id);
    }
  }
}

class _LabelSetTile extends StatelessWidget {
  final LabelSet labelSet;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  const _LabelSetTile({
    required this.labelSet,
    required this.isActive,
    required this.onTap,
    required this.onSetActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: isActive
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.label_outline),
        title: Text(labelSet.name),
        subtitle: Text(
          '${labelSet.labels.length} label${labelSet.labels.length == 1 ? '' : 's'}'
          ' · ${labelSet.labels.take(3).join(', ')}'
          '${labelSet.labels.length > 3 ? '…' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'activate':
                onSetActive();
              case 'edit':
                onTap();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'activate',
              child: Text(isActive ? 'Deactivate' : 'Set as active'),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
