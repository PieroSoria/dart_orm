import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DartEngine {
  Process? _process;
  HttpClient? _client;
  String? _baseUrl;
  bool _started = false;

  Future<void> connect({
    required String enginePath,
    Map<String, String>? env,
  }) async {
    _process = await Process.start(
      enginePath,
      [
        '--engine-protocol',
        'json',
        '--port',
        '0',
        '--enable-raw-queries',
        '--enable-metrics',
      ],
      environment: env,
      mode: ProcessStartMode.normal,
    );

    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      try {
        final log = jsonDecode(line) as Map<String, dynamic>;
        final fields = log['fields'] as Map<String, dynamic>?;
        if (fields != null &&
            fields['message'] == 'Started query engine http server') {
          final port = fields['port'] as int;
          _baseUrl = 'http://127.0.0.1:$port';
          _started = true;
        }
      } catch (_) {}
    });

    _process!.stdout.listen((data) {
      stderr.add(data);
    });

    _process!.exitCode.then((code) {
      _started = false;
      if (code != 0) {
        stderr.writeln('Query engine exited with code: $code');
      }
    });

    await _waitForEngine();
  }

  Future<void> _waitForEngine({Duration timeout = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_started && _baseUrl != null) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('Query engine failed to start within $timeout');
  }

  Future<dynamic> query(Map<String, dynamic> payload) async {
    if (_baseUrl == null || _client == null) {
      throw StateError('Engine not connected. Call connect() first.');
    }

    final body = jsonEncode(payload);
    final url = Uri.parse('$_baseUrl/');

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final request = await _client!.postUrl(url);
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('Content-Length', body.length.toString());
        request.write(body);

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode != 200) {
          throw HttpException(
            'Engine returned status ${response.statusCode}: $responseBody',
            uri: url,
          );
        }

        final decoded = jsonDecode(responseBody);
        return _unwrapTaggedValues(decoded);
      } on SocketException {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }
  }

  dynamic _unwrapTaggedValues(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (value.containsKey('\$type') && value.containsKey('value')) {
        return _unwrapTagged(value);
      }
      return value.map((k, v) => MapEntry(k, _unwrapTaggedValues(v)));
    }
    if (value is List) {
      return value.map(_unwrapTaggedValues).toList();
    }
    return value;
  }

  dynamic _unwrapTagged(Map<String, dynamic> tagged) {
    final type = tagged['\$type'] as String;
    final value = tagged['value'];
    switch (type) {
      case 'BigInt':
        return BigInt.parse(value as String);
      case 'DateTime':
        return DateTime.parse(value as String);
      case 'Decimal':
        return value;
      case 'Bytes':
        return value;
      case 'Json':
        return jsonDecode(value as String);
      default:
        return value;
    }
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _process?.kill();
    _process = null;
    _started = false;
  }
}
