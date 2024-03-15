import 'dart:convert';
import 'dart:io';

import '../adapter.dart';

/// Represents a Docker API adapter for managing containers, networks, and more.
class DockerAPI extends Adapter {
  /// Authentication string for Docker registry.
  String _registryAuth = '';

  /// Constructor for [DockerAPI].
  ///
  /// If [username], [password], and [email] are provided, it initializes
  /// registry authentication.
  DockerAPI({String? username, String? password, String? email}) {
    if (username != null && password != null && email != null) {
      _registryAuth = base64Encode(utf8.encode(jsonEncode({
        'username': username,
        'password': password,
        'serveraddress': 'https://index.docker.io/v1/',
        'email': email,
      })));
    }
  }

  /// Sends a request to the Docker API via the Docker socket.
  ///
  /// Returns a map containing the 'response' and the HTTP 'code'.
  Future<Map<String, dynamic>> _call(String url, String method,
      {dynamic body, List<String> headers = const [], int timeout = -1}) async {
    var httpClient = HttpClient();
    httpClient.connectionTimeout = Duration(seconds: timeout);

    HttpClientRequest request;
    switch (method) {
      case 'GET':
        request = await httpClient.getUrl(Uri.parse(url));
        break;
      case 'POST':
        request = await httpClient.postUrl(Uri.parse(url));
        break;
      case 'DELETE':
        request = await httpClient.deleteUrl(Uri.parse(url));
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    request.headers.add('Content-Type', 'application/json');
    if (_registryAuth.isNotEmpty) {
      request.headers.add('X-Registry-Auth', _registryAuth);
    }
    headers.forEach((header) {
      var parts = header.split(':');
      if (parts.length == 2) {
        request.headers.add(parts[0].trim(), parts[1].trim());
      }
    });

    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }

    HttpClientResponse response = await request.close();
    String responseBody = await response.transform(utf8.decoder).join();

    return {
      'response': responseBody,
      'code': response.statusCode,
    };
  }

  /// Creates a Docker network.
  Future<bool> createNetwork(String name, {bool internal = false}) async {
    var body = jsonEncode({
      'Name': name,
      'Internal': internal,
    });

    var result =
        await _call('http://localhost/networks/create', 'POST', body: body);

    if (result['code'] != 201) {
      throw Exception('Error creating network: ${result['response']}');
    }

    return true;
  }

  /// Removes a Docker network.
  Future<bool> removeNetwork(String name) async {
    var result = await _call('http://localhost/networks/$name', 'DELETE');

    if (result['code'] != 204) {
      throw Exception('Error removing network: ${result['response']}');
    }

    return true;
  }

  /// Connects a container to a network.
  Future<bool> networkConnect(String container, String network) async {
    var body = jsonEncode({
      'Container': container,
    });

    var result = await _call(
        'http://localhost/networks/$network/connect', 'POST',
        body: body);

    if (result['code'] != 200) {
      throw Exception('Error attaching network: ${result['response']}');
    }

    return true;
  }

  /// Disconnects a container from a network.
  Future<bool> networkDisconnect(String container, String network,
      {bool force = false}) async {
    var body = jsonEncode({
      'Container': container,
      'Force': force,
    });

    var result = await _call(
        'http://localhost/networks/$network/disconnect', 'POST',
        body: body);

    if (result['code'] != 200) {
      throw Exception('Error detaching network: ${result['response']}');
    }

    return true;
  }

  /// Pulls a Docker image.
  Future<bool> pull(String image) async {
    var result = await _call('http://localhost/images/create', 'POST', body: {
      'fromImage': image,
    });

    if (result['code'] != 200 && result['code'] != 204) {
      return false;
    } else {
      return true;
    }
  }

    /// Lists all networks.
  Future<List<dynamic>> listNetworks() async {
    var result = await _call('http://localhost/networks', 'GET');
    if (result['code'] != 200) {
      throw Exception('Error listing networks: ${result['response']}');
    }
    return jsonDecode(result['response']);
  }

  /// Lists all containers with optional filters.
  Future<List<dynamic>> list({Map<String, dynamic>? filters}) async {
    var queryFilters = filters != null ? '?filters=${jsonEncode(filters)}' : '';
    var result = await _call('http://localhost/containers/json$queryFilters', 'GET');
    if (result['code'] != 200) {
      throw Exception('Error listing containers: ${result['response']}');
    }
    return jsonDecode(result['response']);
  }

  /// Runs a new container.
  Future<String> run({
    required String image,
    required String name,
    List<String>? command,
    String? entrypoint,
    String? workdir,
    List<String>? volumes,
    Map<String, String>? env,
    String? mountFolder,
    Map<String, String>? labels,
    String? hostname,
    bool? remove,
    String? network,
  }) async {
    var body = jsonEncode({
      'Hostname': hostname,
      'Entrypoint': entrypoint,
      'Image': image,
      'Cmd': command,
      'WorkingDir': workdir,
      'Labels': labels,
      'Env': env?.entries.map((e) => '${e.key}=${e.value}').toList(),
      'HostConfig': {
        'Binds': volumes,
        'AutoRemove': remove,
      },
    });

    var result = await _call('http://localhost/containers/create?name=$name', 'POST', body: body);
    if (result['code'] != 201) {
      throw Exception('Failed to create container: ${result['response']} Response Code: ${result['code']}');
    }

    var id = jsonDecode(result['response'])['Id'];
    await _call('http://localhost/containers/$id/start', 'POST');

    return id;
  }

  /// Executes a command in a running container.
  Future<bool> execute({
    required String containerId,
    required List<String> command,
    Map<String, String>? env,
    int timeout = -1,
  }) async {
    var body = jsonEncode({
      'AttachStdout': true,
      'AttachStderr': true,
      'Cmd': command,
      'Env': env?.entries.map((e) => '${e.key}=${e.value}').toList(),
    });

    var execCreateResult = await _call('http://localhost/containers/$containerId/exec', 'POST', body: body, timeout: timeout);
    if (execCreateResult['code'] != 201) {
      throw Exception('Failed to create exec instance: ${execCreateResult['response']} Response Code: ${execCreateResult['code']}');
    }

    var execId = jsonDecode(execCreateResult['response'])['Id'];
    var execStartResult = await _call('http://localhost/exec/$execId/start', 'POST', body: {'Detach': false, 'Tty': false}, timeout: timeout);

    return execStartResult['code'] == 200;
  }

  /// Removes a container.
  Future<bool> remove(String id, {bool force = false}) async {
    var result = await _call('http://localhost/containers/$id?force=$force', 'DELETE');
    if (result['code'] != 204) {
      throw Exception('Failed to remove container: ${result['response']} Response Code: ${result['code']}');
    }
    return true;
  }

  /// Gets usage stats of a container.
  Future<dynamic> getStats(String containerId) async {
    var result = await _call('http://localhost/containers/$containerId/stats?stream=false', 'GET');
    if (result['code'] != 200) {
      throw Exception('Error getting stats: ${result['response']}');
    }
    return jsonDecode(result['response']);
  }

  /// Connects a container to a network.
  Future<void> connectToNetwork(String containerId, String networkId) async {
    var body = jsonEncode({'Container': containerId});
    var result = await _call('http://localhost/networks/$networkId/connect', 'POST', body: body);
    if (result['code'] != 200) {
      throw Exception('Error connecting to network: ${result['response']}');
    }
  }

  /// Disconnects a container from a network.

}
