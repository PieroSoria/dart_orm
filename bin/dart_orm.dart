import '../lib/src/codegen.dart';
import '../lib/src/protocol.dart';

void main() {
  final handler = _DartOrmGeneratorHandler();
  final protocol = GeneratorProtocol(handler);
  protocol.run();
}

class _DartOrmGeneratorHandler extends GeneratorHandler {
  @override
  Future<Map<String, dynamic>?> onManifest(Map<String, dynamic> config) async {
    return {
      'prettyName': 'Dart ORM',
      'defaultOutput': '../lib/orm',
      'requiresEngines': ['queryEngine'],
    };
  }

  @override
  Future<void> onGenerate(Map<String, dynamic> params) async {
    final codegen = DartCodegen();
    await codegen.generate(params);
  }
}
