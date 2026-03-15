import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/api_config_provider.dart';
import '../providers/label_set_provider.dart';
import '../providers/classification_provider.dart';

class ClassificationScreen extends ConsumerWidget {
  const ClassificationScreen({super.key});

  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classState = ref.watch(classificationProvider);
    final activeLabelSet = ref.watch(activeLabelSetProvider);
    final hasKey = ref.watch(hasApiKeyProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classify Images'),
      ),
      body: Column(
        children: [
          // Status card
          _StatusCard(
            hasApiKey: hasKey,
            activeLabelSetName: activeLabelSet?.name,
            labelCount: activeLabelSet?.labels.length ?? 0,
          ),

          // Pick images section
          if (!classState.isRunning)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Images'),
                    onPressed: hasKey && activeLabelSet != null
                        ? () => _pickImages(context, ref)
                        : null,
                  ),
                  if (_isDesktop) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Pick Folder'),
                      onPressed: hasKey && activeLabelSet != null
                          ? () => _pickFolder(context, ref)
                          : null,
                    ),
                  ],
                  if (!_isDesktop) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      onPressed: hasKey && activeLabelSet != null
                          ? () => _takePhoto(context, ref)
                          : null,
                    ),
                  ],
                ],
              ),
            ),

          // Progress section
          if (classState.isRunning)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: classState.progress),
                  const SizedBox(height: 8),
                  Text(
                    'Classifying ${classState.processedCount} / '
                    '${classState.totalImages}',
                  ),
                  if (classState.currentFile != null)
                    Text(
                      classState.currentFile!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),

          // Live results as they come in
          if (classState.results.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Results (${classState.results.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (classState.isDone)
                    TextButton(
                      onPressed: () => context.push('/results'),
                      child: const Text('View All →'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: classState.results.length,
                itemBuilder: (context, index) {
                  final r = classState.results[index];
                  return ListTile(
                    dense: true,
                    leading: r.error != null
                        ? const Icon(Icons.error_outline, color: Colors.red)
                        : r.isUncertain
                            ? const Icon(Icons.warning_amber,
                                color: Colors.orange)
                            : const Icon(Icons.check_circle,
                                color: Colors.green),
                    title: Text(r.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: r.error != null
                        ? Text(r.error!, style: const TextStyle(color: Colors.red))
                        : Text('${r.label} · ${(r.confidence * 100).toStringAsFixed(0)}%'),
                  );
                },
              ),
            ),
          ],

          // Empty state
          if (!classState.isRunning && classState.results.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Pick images to start classifying'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImages(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      if (paths.isNotEmpty) {
        ref.read(classificationProvider.notifier).classifyImages(paths);
      }
    }
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final dir = Directory(dirPath);
    final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    final paths = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return imageExtensions.contains('.$ext');
        })
        .map((f) => f.path)
        .toList();

    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image files found in this folder')),
        );
      }
      return;
    }

    paths.sort();
    ref.read(classificationProvider.notifier).classifyImages(paths);
  }

  Future<void> _takePhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      ref.read(classificationProvider.notifier).classifyImages([photo.path]);
    }
  }
}

class _StatusCard extends StatelessWidget {
  final bool hasApiKey;
  final String? activeLabelSetName;
  final int labelCount;

  const _StatusCard({
    required this.hasApiKey,
    required this.activeLabelSetName,
    required this.labelCount,
  });

  @override
  Widget build(BuildContext context) {
    final allGood = hasApiKey && activeLabelSetName != null;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allGood ? Icons.check_circle : Icons.info_outline,
                  color: allGood ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  allGood ? 'Ready to classify' : 'Setup required',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'API Key',
              ok: hasApiKey,
              detail: hasApiKey ? 'Configured' : 'Not set — go to Settings',
            ),
            _StatusRow(
              label: 'Label Set',
              ok: activeLabelSetName != null,
              detail: activeLabelSetName != null
                  ? '$activeLabelSetName ($labelCount labels)'
                  : 'None active — go to Label Sets',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ok;
  final String detail;

  const _StatusRow({
    required this.label,
    required this.ok,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check : Icons.close,
            size: 16,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
