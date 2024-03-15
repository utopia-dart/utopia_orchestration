import 'package:collection/collection.dart';

/// A Dart class for representing a container within a container orchestration environment.
/// This class encapsulates information about a container, such as its name, ID, status, and labels.
class Container {
  /// The name of the container.
  String name;

  /// The unique identifier of the container.
  String id;

  /// The current status of the container.
  String status;

  /// A map of labels associated with the container.
  Map<String, String> labels;

  /// Constructs a [Container] instance with optional parameters.
  Container({
    this.name = '',
    this.id = '',
    this.status = '',
    Map<String, String>? labels,
  }) : labels = labels ?? {};

  /// Creates a new [Container] instance from a JSON map.
  Container.fromJson(Map<String, dynamic> json)
      : name = json['name'] ?? '',
        id = json['id'] ?? '',
        status = json['status'] ?? '',
        labels = json['labels'] ?? {};

  /// Returns a JSON map representation of the [Container] instance.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'status': status,
      'labels': labels,
    };
  }

  /// Creates a copy of the current [Container] instance with the given overridden parameters.
  Container copyWith({
    String? name,
    String? id,
    String? status,
    Map<String, String>? labels,
  }) {
    return Container(
      name: name ?? this.name,
      id: id ?? this.id,
      status: status ?? this.status,
      labels: labels ?? Map<String, String>.from(this.labels),
    );
  }

  @override
  String toString() {
    return 'Container(name: $name, id: $id, status: $status, labels: $labels)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Container &&
        other.name == name &&
        other.id == id &&
        other.status == status &&
        MapEquality<String, String>().equals(other.labels, labels);
  }

  @override
  int get hashCode =>
      name.hashCode ^ id.hashCode ^ status.hashCode ^ labels.hashCode;
}
