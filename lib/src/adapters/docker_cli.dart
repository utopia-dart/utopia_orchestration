import 'dart:convert';
import 'dart:io';

import '../adapter.dart';
import '../stats.dart';
import '../container.dart';

class DockerCLI extends Adapter {
  Future<ProcessResult> _execute(String command, List<String> arguments,
      {String? workingDirectory}) async {
    return await Process.run(command, arguments,
        workingDirectory: workingDirectory, runInShell: true);
  }

  DockerCLI({String? username, String? password}) {
    if (username != null && password != null) {
      _execute('docker', ['login', '--username', username, '--password-stdin'],
              workingDirectory: '.')
          .then((result) {
        if (result.exitCode != 0) {
          throw Exception("Docker Error: ${result.stderr}");
        }
      });
    }
  }

  @override
  Future<bool> createNetwork(String name, {bool internal = false}) async {
    var command = ['network', 'create', name];
    if (internal) {
      command.add('--internal');
    }
    var result = await _execute('docker', command);
    return result.exitCode == 0;
  }

  @override
  Future<bool> removeNetwork(String name) async {
    var result = await _execute('docker', ['network', 'rm', name]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> networkConnect(String container, String network) async {
    var result =
        await _execute('docker', ['network', 'connect', network, container]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> networkDisconnect(String container, String network,
      {bool force = false}) async {
    var command = ['network', 'disconnect'];
    if (force) {
      command.add('--force');
    }
    command.addAll([network, container]);
    var result = await _execute('docker', command);
    return result.exitCode == 0;
  }

  @override
  Future<List<Stats>> getStats(
      {String? container, Map<String, String>? filters}) async {
    List<String> containerIds = [];

    if (container == null) {
      // Assuming `list` returns a Future<List<Container>> where Container is a Dart class similar to the PHP version
      var containers = await list(filters: filters);
      containerIds = containers.map((c) => c.id).toList();
    } else {
      containerIds.add(container);
    }

    if (containerIds.isEmpty && filters != null && filters.isNotEmpty) {
      return []; // No containers found
    }

    var result = await Process.run(
      'docker',
      [
        'stats',
        '--no-trunc',
        '--format',
        'json',
        '--no-stream',
        ...containerIds,
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception("Docker Error: ${result.stderr}");
    }

    List<Stats> stats = [];
    var lines = result.stdout.split('\n');

    for (var line in lines) {
      if (line.isEmpty) {
        continue;
      }

      var data = jsonDecode(line);

      stats.add(Stats.fromJson({
        'containerId': data['ID'],
        'containerName': data['Name'],
        'cpuUsage':
            double.tryParse(data['CPUPerc']!.replaceAll('%', '')) ?? 0.0 / 100,
        'memoryUsage':
            double.tryParse(data['MemPerc']!.replaceAll('%', '')) ?? 0.0,
        'diskIO': parseIOStats(data['BlockIO']!),
        'memoryIO': parseIOStats(data['MemUsage']!),
        'networkIO': parseIOStats(data['NetIO']!),
      }));
    }

    return stats;
  }

  @override
  Future<List<dynamic>> listNetworks() async {
    var result = await _execute('docker', [
      'network',
      'ls',
      '--format',
      '{{.ID}} {{.Name}} {{.Driver}} {{.Scope}}'
    ]);
    if (result.exitCode != 0) {
      throw Exception("Docker Error: ${result.stderr}");
    }
    return LineSplitter.split(result.stdout).map((line) {
      var parts = line.split(' ');
      return {
        'id': parts[0],
        'name': parts[1],
        'driver': parts[2],
        'scope': parts[3],
      };
    }).toList();
  }

  @override
  Future<bool> pull(String image) async {
    var result = await _execute('docker', ['pull', image]);
    return result.exitCode == 0;
  }

  @override
  Future<List<Container>> list({Map<String, String>? filters}) async {
    List<String> command = ['ps', '--all', '--format', 'json'];
    if (filters != null) {
      filters.forEach((key, value) {
        command.add('--filter');
        command.add('$key=$value');
      });
    }
    var result = await _execute('docker', command);
    if (result.exitCode != 0) {
      throw Exception("Docker Error: ${result.stderr}");
    }
    return LineSplitter.split(result.stdout).map((line) {
      var details = jsonDecode(line);
      return Container.fromJson({
        'id': details['ID'],
        'name': details['Names'],
        'status': details['Status'],
        'labels': _parseLabels(details['Labels'] ?? ''),
      });
    }).toList();
  }

  Map<String, String> _parseLabels(String input) {
    var pairs = input.split(',');
    var map = <String, String>{};

    for (var pair in pairs) {
      var keyValue = pair.split('=');
      if (keyValue.length == 2) {
        map[keyValue[0]] = keyValue[1];
      }
    }

    return map;
  }

  @override
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
  }) async {
    var commandList = command
            ?.map((value) => value.contains(' ') ? "'$value'" : value)
            .toList() ??
        [];
    var labelString = labels?.entries.map((entry) {
          var label = entry.value.replaceAll("'", "");
          return '--label ${entry.key}=${label.contains(' ') ? "'$label'" : label}';
        }).join(' ') ??
        '';

    var varsList = vars?.entries.map((entry) {
          var key = filterEnvKey(entry.key);
          var value = entry.value.isEmpty ? '' : entry.value;
          return '--env $key=$value';
        }).toList() ??
        [];

    var volumeString =
        volumes?.map((volume) => '--volume $volume ').join(' ') ?? '';

    var time = DateTime.now().millisecondsSinceEpoch;

    var runArguments = [
      'run',
      '-d',
      if (remove) '--rm',
      if (network.isNotEmpty) '--network="$network"',
      if (entrypoint.isNotEmpty) '--entrypoint="$entrypoint"',
      if (cpus > 0) '--cpus=$cpus',
      if (memory > 0) '--memory=${memory}m',
      if (swap > 0) '--memory-swap=${swap}m',
      '--label=$namespace-created=$time',
      '--name=$name',
      if (mountFolder.isNotEmpty) '--volume $mountFolder:/tmp:rw',
      if (volumeString.isNotEmpty) volumeString,
      if (labelString.isNotEmpty) labelString,
      if (workdir.isNotEmpty) '--workdir $workdir',
      if (hostname.isNotEmpty) '--hostname $hostname',
      ...varsList,
      image,
      ...commandList,
    ].where((element) => element.isNotEmpty).toList();

    var result = await _execute('docker', runArguments);
    if (result.exitCode != 0) {
      throw Exception("Docker Error: ${result.stderr}");
    }

    return result.stdout.trim();
  }

  /// Executes a command in a specified container.
  ///
  /// [name] The name of the container where the command will be executed.
  /// [command] The command to execute as a list of strings.
  /// [vars] Optional map of environment variables to set in the format of { 'KEY': 'VALUE' }.
  /// [timeout] Optional timeout in seconds for how long to wait for the command to execute. A value of -1 indicates no timeout.
  /// Returns a Future<bool> indicating success or failure of the command execution.
  ///
  /// Throws an Exception if the command fails or times out.
  @override
  Future<bool> execute(
    String name,
    List<String> command, {
    Map<String, String>? vars,
    int timeout = -1,
  }) async {
    var commandList = command
        .map((value) => value.contains(' ') ? "'$value'" : value)
        .toList();
    var varsList = vars?.entries.map((entry) {
          var key = filterEnvKey(entry.key);
          var value = entry.value.isEmpty ? '' : entry.value;
          return '--env $key=$value';
        }).toList() ??
        [];

    var processResult = await Process.run(
      'docker',
      ['exec', ...varsList, name, ...commandList],
      runInShell: true,
      environment: vars,
    );

    if (processResult.exitCode != 0) {
      if (processResult.exitCode == 124) {
        throw Exception('Command timed out');
      } else {
        throw Exception("Docker Error: ${processResult.stderr}");
      }
    }

    return processResult.exitCode == 0;
  }

  @override
  Future<bool> remove(String name, {bool force = false}) async {
    List<String> command = ['rm'];
    if (force) {
      command.add('--force');
    }
    command.add(name);
    var result = await _execute('docker', command);
    if (result.exitCode != 0 || !result.stdout.contains(name)) {
      throw Exception("Docker Error: ${result.stderr}");
    }
    return true;
  }

  Map<String, double> parseIOStats(String stats) {
    var units = {
      'B': 1,
      'KB': 1000,
      'MB': 1000000,
      'GB': 1000000000,
      'TB': 1000000000000,
      'KiB': 1024,
      'MiB': 1048576,
      'GiB': 1073741824,
      'TiB': 1099511627776,
    };

    var parts = stats.split(' / ');
    var inStr = parts[0];
    var outStr = parts[1];

    String? inUnit;
    String? outUnit;

    units.forEach((unit, value) {
      if (inStr.endsWith(unit)) {
        inUnit = unit;
      }
      if (outStr.endsWith(unit)) {
        outUnit = unit;
      }
    });

    var inMultiply = inUnit == null ? 1 : units[inUnit]!;
    var outMultiply = outUnit == null ? 1 : units[outUnit]!;

    var inValue = double.parse(inStr.replaceAll(inUnit ?? '', '').trim());
    var outValue = double.parse(outStr.replaceAll(outUnit ?? '', '').trim());

    return {
      'in': inValue * inMultiply,
      'out': outValue * outMultiply,
    };
  }
}
