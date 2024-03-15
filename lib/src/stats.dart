import 'package:collection/collection.dart';

/// A Dart class for representing the statistics of a container within a container orchestration environment.
/// This class encapsulates detailed performance metrics such as CPU usage, memory usage, and IO statistics.
class Stats {
  /// The unique identifier of the container.
  final String containerId;

  /// The name of the container.
  final String containerName;

  /// The CPU usage percentage of the container.
  final double cpuUsage;

  /// The memory usage of the container in megabytes.
  final double memoryUsage;

  /// Disk IO statistics of the container, including read and write speeds.
  final Map<String, double> diskIO;

  /// Memory IO statistics of the container, including usage and available memory.
  final Map<String, double> memoryIO;

  /// Network IO statistics of the container, including incoming and outgoing traffic.
  final Map<String, double> networkIO;

  /// Constructs a [Stats] instance with required parameters.
  Stats({
    required this.containerId,
    required this.containerName,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskIO,
    required this.memoryIO,
    required this.networkIO,
  });

  /// Creates a new [Stats] instance from a JSON map.
  Stats.fromJson(Map<String, dynamic> json)
      : containerId = json['containerId'],
        containerName = json['containerName'],
        cpuUsage = json['cpuUsage'].toDouble(),
        memoryUsage = json['memoryUsage'].toDouble(),
        diskIO = Map<String, double>.from(json['diskIO']),
        memoryIO = Map<String, double>.from(json['memoryIO']),
        networkIO = Map<String, double>.from(json['networkIO']);

  /// Returns a JSON map representation of the [Stats] instance.
  Map<String, dynamic> toJson() {
    return {
      'containerId': containerId,
      'containerName': containerName,
      'cpuUsage': cpuUsage,
      'memoryUsage': memoryUsage,
      'diskIO': diskIO,
      'memoryIO': memoryIO,
      'networkIO': networkIO,
    };
  }

  @override
  String toString() {
    return 'Stats(containerId: $containerId, containerName: $containerName, cpuUsage: $cpuUsage, memoryUsage: $memoryUsage, diskIO: $diskIO, memoryIO: $memoryIO, networkIO: $networkIO)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Stats &&
        other.containerId == containerId &&
        other.containerName == containerName &&
        other.cpuUsage == cpuUsage &&
        other.memoryUsage == memoryUsage &&
        MapEquality<String, double>().equals(other.diskIO, diskIO) &&
        MapEquality<String, double>().equals(other.memoryIO, memoryIO) &&
        MapEquality<String, double>().equals(other.networkIO, networkIO);
  }

  @override
  int get hashCode =>
      containerId.hashCode ^
      containerName.hashCode ^
      cpuUsage.hashCode ^
      memoryUsage.hashCode ^
      diskIO.hashCode ^
      memoryIO.hashCode ^
      networkIO.hashCode;
}
