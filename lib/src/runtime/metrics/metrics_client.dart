import '../engine.dart';
import 'metrics_format.dart';

class MetricsClient {
  const MetricsClient(Engine engine) : _engine = engine;

  final Engine _engine;

  Future<String> prometheus({Map<String, String>? globalLabels}) async {
    final result = await _engine.metrics(globalLabels: globalLabels, format: MetricsFormat.prometheus);
    return result.toString();
  }

  Future<Map<String, dynamic>> json({Map<String, String>? globalLabels}) async {
    final result = await _engine.metrics(globalLabels: globalLabels, format: MetricsFormat.json);
    return result as Map<String, dynamic>;
  }
}
