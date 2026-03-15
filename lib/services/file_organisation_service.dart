import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

import '../models/classification_result.dart';
import '../providers/api_config_provider.dart';

/// Provider for the FileOrganisationService singleton.
final fileOrganisationServiceProvider = Provider<FileOrganisationService>((ref) {
  return FileOrganisationService(ref);
});

/// Service responsible for strictly copying, renaming, and logging 
/// classified images into the globally configured Storage path.
class FileOrganisationService {
  final Ref _ref;

  FileOrganisationService(this._ref);

  /// Automatically copy and organize a file into the Gallery disk path.
  Future<void> autoOrganizeFile(ClassificationResult result) async {
    if (result.error != null) return; // Only save successful classifications

    final storageService = _ref.read(secureStorageServiceProvider);
    final destDir = await storageService.getGalleryPath();

    if (destDir == null || destDir.isEmpty) {
      debugPrint('Cannot auto-organize: Storage path not configured.');
      return;
    }

    final metadataMap = <String, Map<String, dynamic>>{};
    final metadataFile = File(p.join(destDir, 'metadata.json'));
    
    // Load existing metadata so we can append
    if (metadataFile.existsSync()) {
      try {
        final content = metadataFile.readAsStringSync();
        final Map<String, dynamic> decoded = jsonDecode(content);
        decoded.forEach((k, v) => metadataMap[k] = v as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Failed to load existing metadata during auto-organize: $e');
      }
    }

    final sourceFile = File(result.filePath);
    if (!sourceFile.existsSync()) {
      debugPrint('Source file missing during auto-organize: ${result.filePath}');
      return;
    }

    // Get original modification time (fallback to now if error)
    DateTime modTime = DateTime.now();
    try {
      modTime = sourceFile.statSync().modified;
    } catch (_) {}

    final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
    final String datePrefix = formatter.format(modTime);

    final safeLabel = result.label.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetDirPath = p.join(destDir, safeLabel);
    final targetDir = Directory(targetDirPath);
    
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (e) {
        debugPrint('Failed to create destination folder $safeLabel: $e');
        return;
      }
    }

    final originalExt = p.extension(result.filePath);
    String baseNewFilename = '${datePrefix}_$safeLabel';
    String targetFilePath = p.join(targetDirPath, '$baseNewFilename$originalExt');
    String finalFilename = '$baseNewFilename$originalExt';
    
    // Handle filename collisions
    int counter = 1;
    while (File(targetFilePath).existsSync()) {
      finalFilename = '${baseNewFilename}_$counter$originalExt';
      targetFilePath = p.join(targetDirPath, finalFilename);
      counter++;
    }
    
    try {
      await sourceFile.copy(targetFilePath);
      
      // Strict verification
      if (!File(targetFilePath).existsSync()) {
        debugPrint('Auto-organize: File copy returned success but file is missing on disk.');
        return;
      }

      // Save to metadata
      metadataMap[finalFilename] = {
        'filename': finalFilename,
        'original_filename': result.filename,
        'label': result.label,
        'confidence': result.confidence,
        'isUncertain': result.isUncertain,
        // The time it was run through the AI layer
        'classifiedAt': DateTime.now().toIso8601String(),
      };
      
      // Save metadata.json back to disk
      try {
        metadataFile.writeAsStringSync(jsonEncode(metadataMap));
      } catch (e) {
        debugPrint('Failed to write metadata during auto-organize: $e');
      }

    } catch (e) {
      debugPrint('Error auto-organizing ${result.filename}: $e');
    }
  }
}
