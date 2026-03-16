import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api_config.dart';
import '../models/classification_result.dart';
import '../utils/constants.dart';
import 'file_organisation_service.dart';
import 'providers/ollama_provider.dart';

/// Service that sends images to AI providers for classification.
class ClassificationService {
  final Dio _dio;
  final Ref _ref;

  ClassificationService(this._ref, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  /// Classify a single image file using the given API config and labels.
  Future<ClassificationResult> classifyImage({
    required File imageFile,
    required ApiConfig apiConfig,
    required List<String> labels,
  }) async {
    final filename = p.basename(imageFile.path);

    // Initial connectivity check for Ollama
    if (apiConfig.provider == ApiProvider.ollama) {
      final ollama = OllamaProvider(dio: _dio);
      if (!await ollama.isRunning()) {
        return ClassificationResult.error(
          filename: filename,
          filePath: imageFile.path,
          errorMessage: 'Ollama is not running. Please start Ollama and try again.',
        );
      }
    }

    try {
      var bytes = await imageFile.readAsBytes();
      var mimeType = _getMimeType(imageFile.path);

      // Always decode and re-encode as JPEG to ensure payload is lean and compatible.
      // Large lossless PNGs (like Linux screenshots) can easily exceed API limits.
      final image = img.decodeImage(bytes);
      if (image != null) {
        img.Image processed = image;
        if (image.width > 1280 || image.height > 1280) {
          processed = img.copyResize(
            image,
            width: image.width > image.height ? 1280 : null,
            height: image.height >= image.width ? 1280 : null,
          );
        }
        // Encode to JPEG with quality 80 to keep file size small.
        bytes = img.encodeJpg(processed, quality: 80);
        mimeType = 'image/jpeg';
      }

      final base64Image = base64Encode(bytes);
      final prompt = AppConstants.classificationPrompt.replaceAll(
        '[LABELS]',
        labels.join(', '),
      );

      var responseText = await _callProvider(apiConfig, base64Image, mimeType, prompt);
      var result = _parseResponse(responseText, filename, imageFile.path, labels);

      // Retry once for Ollama if parsing fails
      if (result.error != null && apiConfig.provider == ApiProvider.ollama) {
        final stricterPrompt = '$prompt\n\nIMPORTANT: You must respond ONLY with the format \'label|confidence\'. Do not include any other text, reasoning, or formatting.';
        responseText = await _callOllama(base64Image, stricterPrompt, apiConfig.model ?? 'llava');
        result = _parseResponse(responseText, filename, imageFile.path, labels);
      }
      
      // Feature: Auto-Organize strictly if we have no errors
      if (result.error == null) {
        final fileOrgService = _ref.read(fileOrganisationServiceProvider);
        await fileOrgService.autoOrganizeFile(result);
      }

      return result;

    } catch (e) {
      return ClassificationResult.error(
        filename: filename,
        filePath: imageFile.path,
        errorMessage: _friendlyError(e),
      );
    }
  }

  /// Helper to call the correct provider based on config.
  Future<String> _callProvider(
    ApiConfig apiConfig,
    String base64Image,
    String mimeType,
    String prompt,
  ) async {
    return switch (apiConfig.provider) {
      ApiProvider.openai => await _callOpenAI(
          apiConfig.apiKey,
          base64Image,
          mimeType,
          prompt,
        ),
      ApiProvider.anthropic => await _callAnthropic(
          apiConfig.apiKey,
          base64Image,
          mimeType,
          prompt,
        ),
      ApiProvider.gemini => await _callGemini(
          apiConfig.apiKey,
          base64Image,
          mimeType,
          prompt,
        ),
      ApiProvider.openrouter => await _callOpenRouter(
          apiConfig.apiKey,
          base64Image,
          mimeType,
          prompt,
          apiConfig.model,
        ),
      ApiProvider.ollama => await _callOllama(
          base64Image,
          prompt,
          apiConfig.model ?? 'llava',
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // OpenRouter — POST https://openrouter.ai/api/v1/chat/completions
  // OpenAI-compatible format
  // ---------------------------------------------------------------------------
  Future<String> _callOpenRouter(
    String apiKey,
    String base64Image,
    String mimeType,
    String prompt,
    String? customModel,
  ) async {
    final modelToUse = (customModel != null && customModel.trim().isNotEmpty)
        ? customModel.trim()
        : 'openrouter/healer-alpha';

    final response = await _dio.post(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/ayo-sam/labi',
          'X-Title': 'Labi Image Classification',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': modelToUse,
        'max_tokens': 50,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      },
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List;
    return (choices[0]['message']['content'] as String).trim();
  }

  // ---------------------------------------------------------------------------
  // OpenAI — POST https://api.openai.com/v1/chat/completions
  // Uses gpt-4o with vision (base64 image in content array)
  // ---------------------------------------------------------------------------
  Future<String> _callOpenAI(
    String apiKey,
    String base64Image,
    String mimeType,
    String prompt,
  ) async {
    final response = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'gpt-4o',
        'max_tokens': 50,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image',
                  'detail': 'low',
                },
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      },
    );

    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List;
    return (choices[0]['message']['content'] as String).trim();
  }

  // ---------------------------------------------------------------------------
  // Anthropic — POST https://api.anthropic.com/v1/messages
  // Uses claude-sonnet-4-20250514 with image content block (base64)
  // ---------------------------------------------------------------------------
  Future<String> _callAnthropic(
    String apiKey,
    String base64Image,
    String mimeType,
    String prompt,
  ) async {
    final response = await _dio.post(
      'https://api.anthropic.com/v1/messages',
      options: Options(
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 50,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mimeType,
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      },
    );

    final data = response.data as Map<String, dynamic>;
    final content = data['content'] as List;
    return (content[0]['text'] as String).trim();
  }

  // ---------------------------------------------------------------------------
  // Google Gemini — POST generativelanguage.googleapis.com
  // Uses gemini-2.0-flash with inlineData
  // ---------------------------------------------------------------------------
  Future<String> _callGemini(
    String apiKey,
    String base64Image,
    String mimeType,
    String prompt,
  ) async {
    final response = await _dio.post(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent?key=$apiKey',
      options: Options(headers: {'Content-Type': 'application/json'}),
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {'mime_type': mimeType, 'data': base64Image},
              },
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': 50},
      },
    );

    final data = response.data as Map<String, dynamic>;
    final candidates = data['candidates'] as List;
    final parts = candidates[0]['content']['parts'] as List;
    return (parts[0]['text'] as String).trim();
  }

  // ---------------------------------------------------------------------------
  // Ollama — POST http://localhost:11434/api/chat
  // ---------------------------------------------------------------------------
  Future<String> _callOllama(
    String base64Image,
    String prompt,
    String model,
  ) async {
    final ollama = OllamaProvider(dio: _dio);
    return await ollama.classify(
      model: model,
      prompt: prompt,
      base64Image: base64Image,
    );
  }

  // ---------------------------------------------------------------------------
  // Response parsing — expects "label|confidence"
  // ---------------------------------------------------------------------------
  ClassificationResult _parseResponse(
    String responseText,
    String filename,
    String filePath,
    List<String> validLabels,
  ) {
    // Try to parse "label|confidence" format
    final parts = responseText.split('|');
    if (parts.length == 2) {
      final label = parts[0].trim();
      final confidence = double.tryParse(parts[1].trim());

      if (confidence != null) {
        // Try to match against valid labels (case-insensitive)
        final matchedLabel = validLabels.firstWhere(
          (l) => l.toLowerCase() == label.toLowerCase(),
          orElse: () => label, // Use as-is if no exact match
        );

        return ClassificationResult(
          filename: filename,
          filePath: filePath,
          label: matchedLabel,
          confidence: confidence.clamp(0.0, 1.0),
        );
      }
    }

    // If parsing fails, return an error result with the raw response
    return ClassificationResult.error(
      filename: filename,
      filePath: filePath,
      errorMessage: 'Unexpected response format: $responseText',
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _getMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      _ => 'image/jpeg', // default fallback
    };
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      if (error.response != null) {
        final status = error.response!.statusCode;
        final body = error.response!.data;
        if (status == 401) return 'Invalid API key (401)';
        if (status == 429) return 'Rate limit exceeded (429)';
        if (status == 400 || status == 404) {
          // Try to extract error message from response body
          if (body is Map && body['error'] is Map) {
            final msg = body['error']['message'];
            if (msg != null) return '$msg ($status)';
          }
          return status == 404 ? 'Not found (404)' : 'Bad request (400)';
        }
        return 'API error ($status)';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Request timed out. Check your connection.';
      }
      return 'Network error: ${error.message}';
    }
    return error.toString();
  }
}
