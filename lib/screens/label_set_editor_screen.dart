import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/label_set.dart';
import '../providers/label_set_provider.dart';

class LabelSetEditorScreen extends ConsumerStatefulWidget {
  final String? labelSetId;

  const LabelSetEditorScreen({super.key, this.labelSetId});

  @override
  ConsumerState<LabelSetEditorScreen> createState() =>
      _LabelSetEditorScreenState();
}

class _LabelSetEditorScreenState extends ConsumerState<LabelSetEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _labelInputController = TextEditingController();
  final List<String> _labels = [];
  bool _saving = false;
  bool _loaded = false;

  bool get isEditing => widget.labelSetId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _labelInputController.dispose();
    super.dispose();
  }

  void _loadExisting(List<LabelSet> labelSets) {
    if (_loaded || !isEditing) return;
    final existing = labelSets.where((ls) => ls.id == widget.labelSetId);
    if (existing.isNotEmpty) {
      _nameController.text = existing.first.name;
      _labels.addAll(existing.first.labels);
      _loaded = true;
    }
  }

  void _addLabel() {
    final text = _labelInputController.text.trim();
    if (text.isEmpty) return;

    // Support comma-separated input
    final newLabels = text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_labels.contains(s))
        .toList();

    if (newLabels.isNotEmpty) {
      setState(() => _labels.addAll(newLabels));
      _labelInputController.clear();
    }
  }

  void _removeLabel(int index) {
    setState(() => _labels.removeAt(index));
  }

  void _reorderLabels(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final label = _labels.removeAt(oldIndex);
      _labels.insert(newIndex, label);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_labels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one label')),
      );
      return;
    }

    setState(() => _saving = true);

    final labelSet = LabelSet(
      id: widget.labelSetId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      labels: List.from(_labels),
    );

    await ref.read(labelSetListProvider.notifier).saveLabelSet(labelSet);

    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelSetsAsync = ref.watch(labelSetListProvider);

    // Load existing data when available
    labelSetsAsync.whenData((labelSets) => _loadExisting(labelSets));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Label Set' : 'New Label Set'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Name field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Label set name',
                  hintText: 'e.g. Biology',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a name';
                  }
                  return null;
                },
              ),
            ),

            // Add label input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _labelInputController,
                      decoration: const InputDecoration(
                        labelText: 'Add labels',
                        hintText: 'Type label or comma-separated list',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addLabel(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addLabel,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

            // Label count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_labels.length} label${_labels.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),

            const Divider(),

            // Label list — reorderable
            Expanded(
              child: _labels.isEmpty
                  ? const Center(
                      child: Text(
                        'No labels added yet.\n'
                        'Type a label above and tap + to add.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _labels.length,
                      onReorder: _reorderLabels,
                      itemBuilder: (context, index) {
                        return ListTile(
                          key: ValueKey('$index-${_labels[index]}'),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(_labels[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _removeLabel(index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
