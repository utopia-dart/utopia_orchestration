/// A Dart class for representing a network within a container orchestration environment.
/// This class encapsulates information about a network, such as its name, ID, driver, and scope.
class Network {
  /// The name of the network.
  String name;

  /// The unique identifier of the network.
  String id;

  /// The driver used by the network.
  String driver;

  /// The scope of the network.
  String scope;

  /// Constructs a [Network] instance with optional parameters.
  Network({
    this.name = '',
    this.id = '',
    this.driver = '',
    this.scope = '',
  });

  /// Creates a new [Network] instance from a JSON map.
  Network.fromJson(Map<String, dynamic> json)
      : name = json['name'] ?? '',
        id = json['id'] ?? '',
        driver = json['driver'] ?? '',
        scope = json['scope'] ?? '';

  /// Returns a JSON map representation of the [Network] instance.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'driver': driver,
      'scope': scope,
    };
  }

  /// Creates a copy of the current [Network] instance with the given overridden parameters.
  Network copyWith({
    String? name,
    String? id,
    String? driver,
    String? scope,
  }) {
    return Network(
      name: name ?? this.name,
      id: id ?? this.id,
      driver: driver ?? this.driver,
      scope: scope ?? this.scope,
    );
  }

  @override
  String toString() {
    return 'Network(name: $name, id: $id, driver: $driver, scope: $scope)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Network &&
        other.name == name &&
        other.id == id &&
        other.driver == driver &&
        other.scope == scope;
  }

  @override
  int get hashCode =>
      name.hashCode ^ id.hashCode ^ driver.hashCode ^ scope.hashCode;
}
