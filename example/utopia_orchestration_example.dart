import 'package:utopia_orchestration/utopia_orchestration.dart';

void main() async {
  final dockerCli = DockerCLI();
  final orchestrator = Orchestration(dockerCli);
  final res =
      await orchestrator.run(image: 'hello-world', name: 'test-hello-world');
  print(res);
  print(await orchestrator.list());
  final stats = await orchestrator.getStats();
  print(stats);
  await orchestrator.remove('test-hello-world');
}
