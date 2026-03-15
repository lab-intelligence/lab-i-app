import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/label_set.dart';
import '../services/label_storage_service.dart';

/// Provider for the LabelStorageService singleton.
final labelStorageServiceProvider = Provider<LabelStorageService>((ref) {
  return LabelStorageService();
});

/// Manages the list of label sets.
class LabelSetListNotifier extends AsyncNotifier<List<LabelSet>> {
  @override
  FutureOr<List<LabelSet>> build() async {
    final service = ref.read(labelStorageServiceProvider);
    return service.getAllLabelSets();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(labelStorageServiceProvider);
      state = AsyncValue.data(await service.getAllLabelSets());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveLabelSet(LabelSet labelSet) async {
    final service = ref.read(labelStorageServiceProvider);
    await service.saveLabelSet(labelSet);
    await refresh();
  }

  Future<void> deleteLabelSet(String id) async {
    final service = ref.read(labelStorageServiceProvider);
    await service.deleteLabelSet(id);
    await refresh();
  }
}

final labelSetListProvider =
    AsyncNotifierProvider<LabelSetListNotifier, List<LabelSet>>(() {
  return LabelSetListNotifier();
});

/// The currently selected (active) label set ID.
final activeLabelSetIdProvider = StateProvider<String?>((ref) => null);

/// The currently active label set.
final activeLabelSetProvider = Provider<LabelSet?>((ref) {
  final activeId = ref.watch(activeLabelSetIdProvider);
  if (activeId == null) return null;

  final labelSets = ref.watch(labelSetListProvider).valueOrNull;
  if (labelSets == null) return null;

  try {
    return labelSets.firstWhere((ls) => ls.id == activeId);
  } catch (_) {
    return null;
  }
});
