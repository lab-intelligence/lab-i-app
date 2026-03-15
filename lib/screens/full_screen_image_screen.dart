import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class FullScreenImageScreen extends ConsumerStatefulWidget {
  final File file;
  final Map<String, dynamic>? metadata;

  const FullScreenImageScreen({
    super.key,
    required this.file,
    this.metadata,
  });

  @override
  ConsumerState<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends ConsumerState<FullScreenImageScreen> {
  void _shareImage() async {
    await Share.shareXFiles([XFile(widget.file.path)]);
  }

  void _showFileInfo() {
    final file = widget.file;
    final meta = widget.metadata;
    final stat = file.statSync();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('File Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filename: ${p.basename(file.path)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Path: ${file.path}'),
                Text('Size: ${(stat.size / 1024).toStringAsFixed(2)} KB'),
                const SizedBox(height: 16),
                const Text('Classification Details',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (meta != null) ...[
                  Text('Label: ${meta['label']}'),
                  Text(
                      'Confidence: ${(meta['confidence'] * 100).toStringAsFixed(1)}%'),
                  Text('Uncertain: ${meta['isUncertain'] == true ? 'Yes' : 'No'}'),
                  if (meta['original_filename'] != null)
                    Text('Original: ${meta['original_filename']}'),
                ] else
                  const Text('No metadata found for this image.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
              'Are you sure you want to delete ${p.basename(widget.file.path)}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                try {
                  widget.file.deleteSync();
                  if (mounted) {
                    Navigator.pop(context, true); // Pop screen with 'true' to signal refresh
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.basename(widget.file.path), style: const TextStyle(fontSize: 16)),
            if (widget.metadata != null)
              Text(
                'Label: ${widget.metadata!['label']} | Conf: ${(widget.metadata!['confidence'] * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareImage,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'File Info',
            onPressed: _showFileInfo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: widget.file.path,
            child: Image.file(widget.file),
          ),
        ),
      ),
    );
  }
}
