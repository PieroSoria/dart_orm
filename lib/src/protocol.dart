import 'dart:convert';
import 'dart:io';

abstract class GeneratorHandler {
  Future<Map<String, dynamic>?> onManifest(Map<String, dynamic> config);
  Future<void> onGenerate(Map<String, dynamic> params);
}

class GeneratorProtocol {
  final GeneratorHandler _handler;

  GeneratorProtocol(this._handler);

  Future<void> run() async {
    while (true) {
      final line = stdin.readLineSync(encoding: utf8);
      if (line == null) break;
      if (line.trim().isEmpty) continue;

      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        await _handleRequest(request);
      } catch (e) {
        _respondError(null, -32700, e.toString());
      }
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> request) async {
    final id = request['id'];
    final method = request['method'] as String?;
    final params = request['params'] as Map<String, dynamic>? ?? {};

    try {
      switch (method) {
        case 'getManifest':
          final manifest = await _handler.onManifest(params);
          _respond(id, {'manifest': manifest});
        case 'generate':
          await _handler.onGenerate(params);
          _respond(id, null);
        default:
          _respond(id, null);
      }
    } catch (e) {
      _respondError(
        id,
        -32000,
        e.toString(),
        e is Error ? e.stackTrace.toString() : null,
      );
    }
  }

  void _respond(dynamic id, dynamic result) {
    stderr.writeln(jsonEncode({'jsonrpc': '2.0', 'result': result, 'id': id}));
  }

  void _respondError(dynamic id, int code, String message, [String? stack]) {
    stderr.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'error': {
          'code': code,
          'message': message,
          if (stack != null) 'data': {'stack': stack},
        },
        'id': id,
      }),
    );
  }
}
