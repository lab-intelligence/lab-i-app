import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../providers/api_config_provider.dart';
import '../providers/classification_provider.dart';
import 'full_screen_image_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with WidgetsBindingObserver {
  String? _directoryPath;
  List<GallerySection> _sections = [];
  Map<String, dynamic> _metadata = {};
  bool _isLoading = true;
  String? _error;

  // Selection & Navigation State
  String? _selectedAlbumLabel;
  final Set<File> _selectedFiles = {};
  bool _isSelectionMode = false;

  final Set<String> _selectedAlbumLabels = {};
  bool _isAlbumSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGallery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadGallery();
    }
  }

  Future<void> _loadGallery() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storage = ref.read(secureStorageServiceProvider);
      final path = await storage.getGalleryPath();

      if (path == null || path.isEmpty) {
        setState(() {
          _directoryPath = null;
          _isLoading = false;
        });
        return;
      }

      final dir = Directory(path);
      if (!dir.existsSync()) {
        setState(() {
          _error = 'The organised folder no longer exists or permissions were lost.';
          _isLoading = false;
        });
        return;
      }

      _directoryPath = path;

      // Load metadata.json
      final metadataFile = File(p.join(path, 'metadata.json'));
      if (metadataFile.existsSync()) {
        try {
          final content = await metadataFile.readAsString();
          _metadata = jsonDecode(content);
        } catch (e) {
          debugPrint('Failed to parse metadata: $e');
        }
      }

      // Group files by label (subfolder)
      final List<GallerySection> sections = [];
      final subDirs = dir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      for (final subDir in subDirs) {
        final label = p.basename(subDir.path);
        // exclude macOS typical hidden dirs
        if (label.startsWith('.')) continue;

        final files = subDir.listSync().whereType<File>().where((file) {
          final ext = p.extension(file.path).toLowerCase();
          return ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif']
              .contains(ext);
        }).toList();

        if (files.isNotEmpty) {
          // Sort by filename
          files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
          sections.add(GallerySection(label: label, files: files));
        }
      }

      setState(() {
        _sections = sections;
        _isLoading = false;

        // Reset navigation/selection if the album no longer exists
        if (_selectedAlbumLabel != null &&
            !_sections.any((s) => s.label == _selectedAlbumLabel)) {
          _selectedAlbumLabel = null;
          _isSelectionMode = false;
          _selectedFiles.clear();
        }

        // Clean up selected labels
        _selectedAlbumLabels.removeWhere(
            (label) => !_sections.any((s) => s.label == label));
        if (_selectedAlbumLabels.isEmpty) _isAlbumSelectionMode = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(File file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        if (_selectedFiles.isEmpty) _isSelectionMode = false;
      } else {
        _selectedFiles.add(file);
        _isSelectionMode = true;
      }
    });
  }

  void _toggleAlbumSelection(String label) {
    setState(() {
      if (_selectedAlbumLabels.contains(label)) {
        _selectedAlbumLabels.remove(label);
        if (_selectedAlbumLabels.isEmpty) _isAlbumSelectionMode = false;
      } else {
        _selectedAlbumLabels.add(label);
        _isAlbumSelectionMode = true;
      }
    });
  }

  void _bulkShare() async {
    if (_selectedFiles.isEmpty) return;
    await Share.shareXFiles(_selectedFiles.map((f) => XFile(f.path)).toList());
    setState(() {
      _isSelectionMode = false;
      _selectedFiles.clear();
    });
  }

  void _bulkShareAlbums() async {
    if (_selectedAlbumLabels.isEmpty) return;
    final List<XFile> xFiles = [];
    for (final label in _selectedAlbumLabels) {
      final section =
          _sections.firstWhere((s) => s.label == label, orElse: () => GallerySection(label: '', files: []));
      if (section.label.isNotEmpty) {
        xFiles.addAll(section.files.map((f) => XFile(f.path)));
      }
    }

    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(xFiles);
    }

    setState(() {
      _isAlbumSelectionMode = false;
      _selectedAlbumLabels.clear();
    });
  }

  Future<void> _bulkDeleteFiles() async {
    final confirmed = await _showDeleteConfirmation(
        'Delete ${_selectedFiles.length} images?');
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      for (final file in _selectedFiles) {
        if (file.existsSync()) file.deleteSync();
        final filename = p.basename(file.path);
        _metadata.remove(filename);
      }
      // Update metadata.json
      if (_directoryPath != null) {
        final metaFile = File(p.join(_directoryPath!, 'metadata.json'));
        await metaFile.writeAsString(jsonEncode(_metadata));
      }
      _selectedFiles.clear();
      _isSelectionMode = false;
      await _loadGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bulkDeleteAlbums() async {
    final confirmed = await _showDeleteConfirmation(
        'Delete ${_selectedAlbumLabels.length} albums?');
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      if (_directoryPath != null) {
        for (final label in _selectedAlbumLabels) {
          final albumDir = Directory(p.join(_directoryPath!, label));
          if (albumDir.existsSync()) {
            // Remove filenames from metadata before deleting folder
            final files = albumDir.listSync().whereType<File>();
            for (final file in files) {
              _metadata.remove(p.basename(file.path));
            }
            albumDir.deleteSync(recursive: true);
          }
        }
        // Update metadata.json
        final metaFile = File(p.join(_directoryPath!, 'metadata.json'));
        await metaFile.writeAsString(jsonEncode(_metadata));
      }
      _selectedAlbumLabels.clear();
      _isAlbumSelectionMode = false;
      await _loadGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showDeleteConfirmation(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(classificationProvider, (previous, next) {
      if (previous?.isRunning == true && next.isRunning == false) {
        _loadGallery();
      }
    });

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load gallery'),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadGallery,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_directoryPath == null || _sections.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No organized images found.'),
              Text('Go classify some images first!',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Determine what to show
    if (_selectedAlbumLabel == null) {
      return _buildAlbumView();
    } else {
      final section = _sections.firstWhere((s) => s.label == _selectedAlbumLabel);
      return _buildGridView(section);
    }
  }

  Widget _buildAlbumView() {
    return Scaffold(
      appBar: AppBar(
        leading: _isAlbumSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isAlbumSelectionMode = false;
                    _selectedAlbumLabels.clear();
                  });
                },
              )
            : null,
        title: Text(_isAlbumSelectionMode
            ? '${_selectedAlbumLabels.length} Selected'
            : 'Albums'),
        centerTitle: true,
        actions: [
          if (_isAlbumSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _bulkShareAlbums,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _bulkDeleteAlbums,
            ),
          ],
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final section = _sections[index];
          final latestFile = section.files.last;
          final isSelected = _selectedAlbumLabels.contains(section.label);

          return GestureDetector(
            onTap: () {
              if (_isAlbumSelectionMode) {
                _toggleAlbumSelection(section.label);
              } else {
                setState(() {
                  _selectedAlbumLabel = section.label;
                });
              }
            },
            onLongPress: () {
              _toggleAlbumSelection(section.label);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          latestFile,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black45 : Colors.transparent,
                            gradient: isSelected
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.5),
                                    ],
                                  ),
                          ),
                        ),
                        if (_isAlbumSelectionMode)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white,
                              size: 24,
                            ),
                          ),
                        if (!_isAlbumSelectionMode)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${section.files.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(GallerySection section) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_isSelectionMode ? Icons.close : Icons.arrow_back),
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _isSelectionMode = false;
                _selectedFiles.clear();
              });
            } else {
              setState(() => _selectedAlbumLabel = null);
            }
          },
        ),
        title: Text(_isSelectionMode
            ? '${_selectedFiles.length} Selected'
            : section.label),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _bulkShare,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _bulkDeleteFiles,
            ),
          ],
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: section.files.length,
        itemBuilder: (context, index) {
          final file = section.files[index];
          final filename = p.basename(file.path);
          final meta = _metadata[filename];
          final isUncertain = meta?['isUncertain'] == true;
          final isSelected = _selectedFiles.contains(file);

          return GestureDetector(
            onTap: () async {
              if (_isSelectionMode) {
                _toggleSelection(file);
              } else {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageScreen(
                      file: file,
                      metadata: meta,
                    ),
                  ),
                );
                if (result == true) {
                  _loadGallery();
                }
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                _toggleSelection(file);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: file.path,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                  ),
                ),
                if (_isSelectionMode)
                  Container(
                    color: isSelected
                        ? Colors.black45
                        : Colors.transparent,
                  ),
                if (_isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                if (!_isSelectionMode && isUncertain)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.warning, color: Colors.orange, size: 16),
                  ),
                if (!_isSelectionMode && meta != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(meta['confidence'] * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GallerySection {
  final String label;
  final List<File> files;

  GallerySection({required this.label, required this.files});
}
