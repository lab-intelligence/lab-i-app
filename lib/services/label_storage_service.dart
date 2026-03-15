import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/label_set.dart';
import '../utils/constants.dart';

/// Service for storing and retrieving label sets using Hive.
class LabelStorageService {
  Box? _box;

  Future<Box> get box async {
    _box ??= await Hive.openBox(AppConstants.labelSetsBox);
    return _box!;
  }

  /// Get all label sets.
  Future<List<LabelSet>> getAllLabelSets() async {
    final b = await box;
    final List<LabelSet> labelSets = [];
    for (final key in b.keys) {
      final raw = b.get(key);
      if (raw != null) {
        final map = Map<String, dynamic>.from(jsonDecode(raw as String));
        labelSets.add(LabelSet.fromJson(map));
      }
    }
    labelSets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return labelSets;
  }

  /// Get a single label set by ID.
  Future<LabelSet?> getLabelSet(String id) async {
    final b = await box;
    final raw = b.get(id);
    if (raw == null) return null;
    return LabelSet.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  /// Save or update a label set.
  Future<void> saveLabelSet(LabelSet labelSet) async {
    final b = await box;
    await b.put(labelSet.id, jsonEncode(labelSet.toJson()));
  }

  /// Delete a label set.
  Future<void> deleteLabelSet(String id) async {
    final b = await box;
    await b.delete(id);
  }
}
