import 'package:utopia_orchestration/utopia_orchestration.dart';

void main() async {
  final cli = DockerCLI();
  // cli.remove('test-hello-world');
  final res = await cli.run('hello-world', 'test-hello-world');
  print(res);
  print(await cli.list());
  final stats = await cli.getStats(container: 'test-hello-world');
  print(stats);
  await cli.remove('test-hello-world');
}
