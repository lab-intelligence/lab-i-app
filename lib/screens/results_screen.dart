import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../providers/classification_provider.dart';
import '../models/classification_result.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _isExporting = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> _exportCsv(List<ClassificationResult> results) async {
    if (results.isEmpty) return;

    setState(() => _isExporting = true);

    try {
      final rows = [
        ['Filename', 'File Path', 'Label', 'Confidence', 'Uncertain', 'Error'],
        ...results.map((r) => [
              r.filename,
              r.filePath,
              r.label,
              r.confidence.toStringAsFixed(3),
              r.isUncertain ? 'Yes' : 'No',
              r.error ?? '',
            ])
      ];

      final csvData = const ListToCsvConverter().convert(rows);
      final defaultFileName = 'labi_results_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (_isDesktop) {
        // Desktop: Ask where to save the file
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV Export',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(csvData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported to $outputFile')),
            );
          }
        }
      } else {
        // Mobile: Save to temp dir and share
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, defaultFileName));
        await tempFile.writeAsString(csvData);

        final xFile = XFile(tempFile.path, mimeType: 'text/csv');
        await Share.shareXFiles(
          [xFile],
          text: 'Lab-i Classification Results',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classState = ref.watch(classificationProvider);
    final results = classState.results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          if (results.isNotEmpty)
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              tooltip: 'Export to CSV',
              onPressed: _isExporting ? null : () => _exportCsv(results),
            ),
        ],
      ),
      body: results.isEmpty
          ? const Center(
              child: Text('No results yet.'),
            )
          : ListView.separated(
              itemCount: results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = results[index];

                return ListTile(
                  leading: r.error != null
                      ? const Icon(Icons.error_outline, color: Colors.red)
                      : r.isUncertain
                          ? const Icon(Icons.warning_amber, color: Colors.orange)
                          : const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(r.filename),
                  subtitle: r.error != null
                      ? Text(r.error!, style: const TextStyle(color: Colors.red))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Label: ${r.label}'),
                            Text(
                              'Confidence: ${(r.confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: r.isUncertain
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                  isThreeLine: r.error == null,
                );
              },
            ),
    );
  }
}
