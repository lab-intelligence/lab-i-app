/// Result of classifying a single image.
class ClassificationResult {
  final String filename;
  final String filePath;
  final String label;
  final double confidence;
  final bool isUncertain;
  final String? error;

  ClassificationResult({
    required this.filename,
    required this.filePath,
    required this.label,
    required this.confidence,
    this.error,
  }) : isUncertain = confidence < 0.6;

  /// Create an error result for when classification fails.
  factory ClassificationResult.error({
    required String filename,
    required String filePath,
    required String errorMessage,
  }) {
    return ClassificationResult(
      filename: filename,
      filePath: filePath,
      label: 'ERROR',
      confidence: 0.0,
      error: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'filePath': filePath,
        'label': label,
        'confidence': confidence,
        'isUncertain': isUncertain,
        'error': error,
      };

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    return ClassificationResult(
      filename: json['filename'] as String,
      filePath: json['filePath'] as String,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      error: json['error'] as String?,
    );
  }
}
