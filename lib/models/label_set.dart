/// A named collection of classification labels.
class LabelSet {
  final String id;
  final String name;
  final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;

  LabelSet({
    required this.id,
    required this.name,
    required this.labels,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  LabelSet copyWith({
    String? name,
    List<String>? labels,
  }) {
    return LabelSet(
      id: id,
      name: name ?? this.name,
      labels: labels ?? List.from(this.labels),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'labels': labels,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LabelSet.fromJson(Map<String, dynamic> json) {
    return LabelSet(
      id: json['id'] as String,
      name: json['name'] as String,
      labels: List<String>.from(json['labels'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
