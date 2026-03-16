import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_config_provider.dart';

/// Manages the application theme mode.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  FutureOr<ThemeMode> build() async {
    final service = ref.read(secureStorageServiceProvider);
    final savedMode = await service.getThemeMode();
    
    if (savedMode == null) return ThemeMode.system;
    
    return ThemeMode.values.firstWhere(
      (m) => m.name == savedMode,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    final service = ref.read(secureStorageServiceProvider);
    await service.saveThemeMode(mode.name);
  }
}

/// Provider for the theme mode state.
final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
