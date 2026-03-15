/// Supported API providers for image classification.
enum ApiProvider {
  openai('OpenAI'),
  anthropic('Anthropic'),
  gemini('Google Gemini'),
  openrouter('OpenRouter');

  const ApiProvider(this.displayName);
  final String displayName;

  static ApiProvider fromString(String value) {
    return ApiProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ApiProvider.openai,
    );
  }
}

/// Holds the user's API configuration.
class ApiConfig {
  final ApiProvider provider;
  final String apiKey;
  final String? model;

  const ApiConfig({
    required this.provider,
    required this.apiKey,
    this.model,
  });

  bool get isValid => apiKey.isNotEmpty;

  ApiConfig copyWith({
    ApiProvider? provider,
    String? apiKey,
    String? model,
  }) {
    return ApiConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}
