import 'stats.dart';
import 'container.dart';

/// An abstract class to define a generic adapter interface for orchestrating containers.
/// This class provides the structure for managing container lifecycle, networking, and resource allocation.
abstract class Adapter {
  /// The namespace to isolate resources within.
  String namespace = 'utopia';

  /// The number of CPU cores allocated to the container. Defaults to 0, meaning not specified.
  int cpus = 0;

  /// The amount of memory allocated to the container in MB. Defaults to 0, meaning not specified.
  int memory = 0;

  /// The amount of swap space allocated to the container in MB. Defaults to 0, meaning not specified.
  int swap = 0;

  /// Filters environment variable keys to ensure they only contain valid characters.
  ///
  /// [string] The input string to filter.
  /// Returns a string with only valid characters for environment variable keys.
  String filterEnvKey(String string) {
    return string.replaceAll(RegExp('[^A-Za-z0-9_\\.-]'), '');
  }

  /// Creates a network.
  ///
  /// [name] The name of the network.
  /// [internal] Specifies whether the network is internal. Defaults to false.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> createNetwork(String name, {bool internal = false});

  /// Removes a network.
  ///
  /// [name] The name of the network to remove.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> removeNetwork(String name);

  /// Connects a container to a network.
  ///
  /// [container] The container to connect.
  /// [network] The network to connect to.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> networkConnect(String container, String network);

  /// Disconnects a container from a network.
  ///
  /// [container] The container to disconnect.
  /// [network] The network to disconnect from.
  /// [force] Whether to forcibly disconnect the container. Defaults to false.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> networkDisconnect(String container, String network,
      {bool force = false});

  /// Lists available networks.
  ///
  /// Returns a Future<List<dynamic>> of network information.
  Future<List<dynamic>> listNetworks();

  /// Retrieves usage statistics for containers.
  ///
  /// [container] Optional specific container ID to get stats for. If null, stats for all containers are returned.
  /// [filters] Optional filters to apply.
  /// Returns a Future<List<dynamic>> of container statistics.
  Future<List<Stats>> getStats(
      {String? container, Map<String, String>? filters});

  /// Pulls an image.
  ///
  /// [image] The image to pull.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> pull(String image);

  /// Lists containers.
  ///
  /// [filters] Optional filters to apply.
  /// Returns a Future<List<dynamic>> of container information.
  Future<List<Container>> list({Map<String, String>? filters});

  /// Runs a container.
  ///
  /// This method creates and runs a new container, returning a Future<String> containing the container ID on success.
  Future<String> run(
    String image,
    String name, {
    List<String>? command,
    String entrypoint = '',
    String workdir = '',
    List<String>? volumes,
    Map<String, String>? vars,
    String mountFolder = '',
    Map<String, String>? labels,
    String hostname = '',
    bool remove = false,
    String network = '',
  });

  /// Executes a command in a container.
  ///
  /// [name] The container name.
  /// [command] The command to execute.
  /// [vars] Optional environment variables to set.
  /// [timeout] Optional timeout in seconds.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> execute(String name, List<String> command,
      {Map<String, String>? vars, int timeout = -1});

  /// Removes a container.
  ///
  /// [name] The name of the container to remove.
  /// [force] Whether to forcibly remove the container. Defaults to false.
  /// Returns a Future<bool> indicating success or failure.
  Future<bool> remove(String name, {bool force = false});

  /// Sets the namespace for container operations.
  ///
  /// [namespace] The namespace to set.
  /// Returns the current instance for chaining.
  Adapter setNamespace(String namespace) {
    this.namespace = namespace;
    return this;
  }

  /// Sets the number of CPU cores for container operations.
  ///
  /// [cpus] The number of CPU cores to allocate.
  /// Returns the current instance for chaining.
  Adapter setCpus(int cpus) {
    this.cpus = cpus;

    return this;
  }

  /// Sets the amount of memory for container operations.
  ///
  /// [memory] The amount of memory in MB to allocate.
  /// Returns the current instance for chaining.
  Adapter setMemory(int memory) {
    this.memory = memory;
    return this;
  }

  /// Sets the amount of swap memory for container operations.
  ///
  /// [swap] The amount of swap memory in MB to allocate.
  /// Returns the current instance for chaining.
  Adapter setSwap(int swap) {
    this.swap = swap;
    return this;
  }
}
