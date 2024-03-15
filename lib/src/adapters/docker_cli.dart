import 'dart:convert';
import 'dart:io';

class DockerCLI {
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

  Future<bool> createNetwork(String name, {bool internal = false}) async {
    var command = ['network', 'create', name];
    if (internal) {
      command.add('--internal');
    }
    var result = await _execute('docker', command);
    return result.exitCode == 0;
  }

  Future<bool> removeNetwork(String name) async {
    var result = await _execute('docker', ['network', 'rm', name]);
    return result.exitCode == 0;
  }

  Future<bool> networkConnect(String container, String network) async {
    var result =
        await _execute('docker', ['network', 'connect', network, container]);
    return result.exitCode == 0;
  }

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

  Future<Map<String, dynamic>> getStats(
      {String? container, Map<String, String>? filters}) async {
    List<String> command = ['stats', '--no-stream', '--format', 'json', '--no-stream', '--no-trunc'];
    if (container != null) {
      command.add(container);
    }
    var result = await _execute('docker', command);
    if (result.exitCode != 0) {
      throw Exception("Docker Error: ${result.stderr}");
    }

    final stat = jsonDecode(result.stdout);
    print(stat);
    return {
      'id': stat['ID'],
      'name': stat['Name'],
      'cpuUsage': double.parse(stat['CPUPerc'].replaceAll('%', '')) / 100,
      'memoryUsage':
          double.parse(stat['MemPerc'].replaceAll('%', '')) / 100,
      'diskIO': parseIOStats(stat['BlockIO']),
      'memoryIO': parseIOStats(stat['MemUsage']),
      'networkIO': parseIOStats(stat['NetIO']),
    };
  }

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

  Future<bool> pull(String image) async {
    var result = await _execute('docker', ['pull', image]);
    return result.exitCode == 0;
  }

  Future<List<dynamic>> list({Map<String, String>? filters}) async {
    List<String> command = [
      'ps',
      '--all',
      '--format',
      '{{.ID}} {{.Names}} {{.Status}}'
    ];
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
      var parts = line.split(' ');
      return {
        'id': parts[0],
        'name': parts[1],
        'status': parts.sublist(2).join(' '),
      };
    }).toList();
  }

  Future<String> run(String image, String name,
      {List<String>? command, Map<String, String>? vars}) async {
    List<String> dockerCommand = ['run', '-d', '--name', name, image];
    if (command != null) {
      dockerCommand.addAll(command);
    }
    if (vars != null) {
      vars.forEach((key, value) {
        dockerCommand.add('-e');
        dockerCommand.add('$key=$value');
      });
    }
    var result = await _execute('docker', dockerCommand);
    if (result.exitCode != 0) {
      throw Exception("Docker Error: ${result.stderr}");
    }
    return result.stdout.trim();
  }

  Future<bool> execute(String container, List<String> command,
      {int timeout = -1}) async {
    var result = await _execute('docker', ['exec', container] + command);
    if (result.exitCode != 0) {
      if (result.exitCode == 124) {
        throw Exception('Command timed out');
      } else {
        throw Exception("Docker Error: ${result.stderr}");
      }
    }
    return true;
  }

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
