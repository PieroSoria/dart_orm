import 'dart:async';
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
    final completer = Completer<void>();

    stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) async {
        if (line.trim().isEmpty) return;
        try {
          final request = jsonDecode(line) as Map<String, dynamic>;
          await _handleRequest(request);
        } catch (e) {
          stderr.writeln(jsonEncode({
            'jsonrpc': '2.0',
            'error': {'code': -32700, 'message': e.toString()},
            'id': null,
          }));
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    // stdin.resume();
    return completer.future;
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
      _respondError(id, -32000, e.toString(), e is Error ? e.stackTrace.toString() : null);
    }
  }

  void _respond(dynamic id, dynamic result) {
    stderr.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'result': result,
      'id': id,
    }));
  }

  void _respondError(dynamic id, int code, String message, [String? stack]) {
    stderr.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'error': {
        'code': code,
        'message': message,
        'data': stack != null ? {'stack': stack} : null,
      },
      'id': id,
    }));
  }
}
