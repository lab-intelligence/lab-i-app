import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/classification_result.dart';
import '../providers/api_config_provider.dart';
import '../providers/label_set_provider.dart';
import '../services/classification_service.dart';

/// Provider for the ClassificationService singleton.
final classificationServiceProvider = Provider<ClassificationService>((ref) {
  return ClassificationService(ref);
});

/// State for an ongoing classification job.
class ClassificationState {
  final List<ClassificationResult> results;
  final int totalImages;
  final int processedCount;
  final bool isRunning;
  final String? currentFile;

  const ClassificationState({
    this.results = const [],
    this.totalImages = 0,
    this.processedCount = 0,
    this.isRunning = false,
    this.currentFile,
  });

  double get progress =>
      totalImages > 0 ? processedCount / totalImages : 0.0;

  bool get isDone => !isRunning && processedCount > 0;

  ClassificationState copyWith({
    List<ClassificationResult>? results,
    int? totalImages,
    int? processedCount,
    bool? isRunning,
    String? currentFile,
  }) {
    return ClassificationState(
      results: results ?? this.results,
      totalImages: totalImages ?? this.totalImages,
      processedCount: processedCount ?? this.processedCount,
      isRunning: isRunning ?? this.isRunning,
      currentFile: currentFile ?? this.currentFile,
    );
  }
}

/// Manages the classification workflow.
class ClassificationNotifier extends Notifier<ClassificationState> {
  @override
  ClassificationState build() => const ClassificationState();

  /// Run classification on a list of image file paths.
  Future<void> classifyImages(List<String> imagePaths) async {
    final apiConfig = ref.read(apiConfigProvider).valueOrNull;
    if (apiConfig == null || !apiConfig.isValid) {
      return;
    }

    final activeLabelSet = ref.read(activeLabelSetProvider);
    if (activeLabelSet == null) {
      return;
    }

    final service = ref.read(classificationServiceProvider);

    state = ClassificationState(
      totalImages: imagePaths.length,
      processedCount: 0,
      isRunning: true,
      results: [],
    );

    final results = <ClassificationResult>[];

    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      final file = File(path);

      state = state.copyWith(
        currentFile: file.uri.pathSegments.last,
        processedCount: i,
      );

      final result = await service.classifyImage(
        imageFile: file,
        apiConfig: apiConfig,
        labels: activeLabelSet.labels,
      );

      results.add(result);

      state = state.copyWith(
        results: List.from(results),
        processedCount: i + 1,
      );
    }

    state = state.copyWith(
      isRunning: false,
      currentFile: null,
    );
  }

  /// Clear all results.
  void clearResults() {
    state = const ClassificationState();
  }
}

final classificationProvider =
    NotifierProvider<ClassificationNotifier, ClassificationState>(() {
  return ClassificationNotifier();
});
