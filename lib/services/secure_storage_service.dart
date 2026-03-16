import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import '../models/api_config.dart';

/// Service for securely storing and retrieving the API key and provider.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Save the API configuration securely.
  Future<void> saveApiConfig(ApiConfig config) async {
    await _storage.write(
      key: AppConstants.apiKeyStorageKey,
      value: config.apiKey,
    );
    await _storage.write(
      key: AppConstants.apiProviderStorageKey,
      value: config.provider.name,
    );
    if (config.provider == ApiProvider.ollama) {
      await _storage.write(
        key: AppConstants.ollamaModelStorageKey,
        value: config.model ?? 'llava',
      );
      await _storage.delete(key: AppConstants.apiModelStorageKey);
    } else {
      if (config.model != null && config.model!.isNotEmpty) {
        await _storage.write(
          key: AppConstants.apiModelStorageKey,
          value: config.model,
        );
      } else {
        await _storage.delete(key: AppConstants.apiModelStorageKey);
      }
      await _storage.delete(key: AppConstants.ollamaModelStorageKey);
    }
  }

  /// Read the stored API configuration, or null if not set.
  Future<ApiConfig?> readApiConfig() async {
    final apiKey = await _storage.read(key: AppConstants.apiKeyStorageKey);
    final providerStr =
        await _storage.read(key: AppConstants.apiProviderStorageKey);
    final modelStr = await _storage.read(key: AppConstants.apiModelStorageKey);

    final provider = providerStr != null
        ? ApiProvider.fromString(providerStr)
        : ApiProvider.openai;

    if (provider == ApiProvider.ollama) {
      final ollamaModel = await _storage.read(key: AppConstants.ollamaModelStorageKey);
      return ApiConfig(
        provider: provider,
        apiKey: apiKey ?? '',
        model: ollamaModel ?? 'llava',
      );
    }

    if (apiKey == null || apiKey.isEmpty) return null;

    return ApiConfig(provider: provider, apiKey: apiKey, model: modelStr);
  }

  /// Delete the stored API configuration.
  Future<void> deleteApiConfig() async {
    await _storage.delete(key: AppConstants.apiKeyStorageKey);
    await _storage.delete(key: AppConstants.apiProviderStorageKey);
    await _storage.delete(key: AppConstants.apiModelStorageKey);
    await _storage.delete(key: AppConstants.ollamaModelStorageKey);
  }

  /// Check whether an API key is stored.
  Future<bool> hasApiKey() async {
    final apiKey = await _storage.read(key: AppConstants.apiKeyStorageKey);
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Save the last chosen gallery path securely.
  Future<void> saveGalleryPath(String path) async {
    await _storage.write(key: AppConstants.lastGalleryPathKey, value: path);
  }

  /// Read the stored gallery path, or null if not set.
  Future<String?> getGalleryPath() async {
    return await _storage.read(key: AppConstants.lastGalleryPathKey);
  }

  /// Save the theme mode.
  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: AppConstants.themeModeStorageKey, value: mode);
  }

  /// Read the stored theme mode.
  Future<String?> getThemeMode() async {
    return await _storage.read(key: AppConstants.themeModeStorageKey);
  }
}
