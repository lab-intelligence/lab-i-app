/// Constants used throughout the Lab-i app.
class AppConstants {
  AppConstants._();

  // Secure storage keys
  static const String apiKeyStorageKey = 'labi_api_key';
  static const String apiProviderStorageKey = 'labi_api_provider';
  static const String apiModelStorageKey = 'labi_api_model';
  static const String lastGalleryPathKey = 'labi_last_gallery_path';
  static const String themeModeStorageKey = 'labi_theme_mode';
  static const String ollamaModelStorageKey = 'ollama_model';

  // Hive box names
  static const String labelSetsBox = 'label_sets';
  static const String classificationResultsBox = 'classification_results';

  // Classification prompt template
  static const String classificationPrompt =
      'Classify this image using exactly one of the following labels: '
      '[LABELS]. Respond with only the label and a confidence score '
      'between 0 and 1. Format: label|confidence';

  // Confidence threshold
  static const double uncertaintyThreshold = 0.6;
}
