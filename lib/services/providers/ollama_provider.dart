import 'package:dio/dio.dart';

class OllamaProvider {
  final Dio _dio;
  static const String _baseUrl = 'http://localhost:11434';

  OllamaProvider({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  /// Check if Ollama is running.
  Future<bool> isRunning() async {
    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send a classification request to Ollama.
  Future<String> classify({
    required String model,
    required String prompt,
    required String base64Image,
  }) async {
    try {
      final response = await _dio.post(
        '/api/chat',
        data: {
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
              'images': [base64Image],
            }
          ],
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return (data['message']['content'] as String).trim();
      } else if (response.statusCode == 404) {
        throw 'Model not found. Make sure you have run: ollama pull $model';
      } else {
        throw 'Ollama error: ${response.statusMessage ?? "Unknown error"}';
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw 'Ollama is not running. Please start Ollama and try again.';
      }
      if (e.response?.statusCode == 404) {
        throw 'Model not found. Make sure you have run: ollama pull $model';
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw 'Ollama took too long. Your device may be too slow for this model, or the model is still loading.';
      }
      
      final errorData = e.response?.data;
      if (errorData is Map && errorData['error'] != null) {
        throw errorData['error'];
      }
      
      throw 'Network error: ${e.message}';
    } catch (e) {
      rethrow;
    }
  }
}
