import 'dart:convert';
import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dart_orm/generator_helper.dart';
import 'package:dart_orm/version.dart';
import 'package:path/path.dart';

import 'src/generator.dart';
import 'src/download_engine.dart';

final _log = File('dart_orm_generator.log');

void main() async {
  await _log.writeAsString('=== Generator started at ${DateTime.now()} ===\n');

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());

  await for (final line in lines) {
    await _log.writeAsString('RECV: $line\n', mode: FileMode.append);

    if (line.trim().isEmpty) continue;

    Map request;
    try {
      request = jsonDecode(line) as Map;
    } catch (e) {
      await _log.writeAsString('Failed to parse JSON: $e\n', mode: FileMode.append);
      continue;
    }

    final method = request['method'] as String?;
    final params = request['params'] as Map? ?? {};
    final id = request['id'];

    if (method == 'getManifest') {
      await _log.writeAsString('Handling getManifest\n', mode: FileMode.append);
      final config = GeneratorConfig.fromJson(params.cast());
      final manifest = GeneratorManifest(
        prettyName: 'Dart ORM',
        defaultOutput: 'generated_dart_client',
        version: 'v$version',
      );

      final response = jsonEncode({
        'jsonrpc': '2.0',
        'result': {'manifest': manifest.toJson()},
        'id': id,
      });

      await _log.writeAsString('SEND: $response\n', mode: FileMode.append);
      stdout.writeln(response);
      await stdout.flush();
    } else if (method == 'generate') {
      await _log.writeAsString('Handling generate\n', mode: FileMode.append);
      try {
        final options = GeneratorOptions.fromJson(params);
        await _generate(options);

        final response = jsonEncode({
          'jsonrpc': '2.0',
          'result': null,
          'id': id,
        });

        await _log.writeAsString('SEND: $response\n', mode: FileMode.append);
        stdout.writeln(response);
        await stdout.flush();
        await _log.writeAsString('Generate done, closing\n', mode: FileMode.append);
        break;
      } catch (e, st) {
        await _log.writeAsString('Generate ERROR: $e\n$st\n', mode: FileMode.append);
        final response = jsonEncode({
          'jsonrpc': '2.0',
          'error': {'code': -32000, 'message': e.toString()},
          'id': id,
        });
        stdout.writeln(response);
        await stdout.flush();
      }
    } else {
      await _log.writeAsString('Unknown method: $method\n', mode: FileMode.append);
    }
  }

  await _log.writeAsString('Generator exiting\n', mode: FileMode.append);
}

Future<void> _generate(GeneratorOptions options) async {
  if (options.generator.output == null) {
    throw StateError('No output directory specified');
  }

  final generator = Generator(options);
  final libraries = generator.generate();
  final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  for (final (filename, library) in libraries) {
    final emitter = DartEmitter.scoped(useNullSafetySyntax: true, orderDirectives: true);
    final source = library.accept(emitter);
    final formated = formatter.format(source.toString());
    final output = await File(join(options.generator.output!.value, filename)).autoCreate();
    await output.writeAsString(formated);
  }

  await downloadEngine(options);
}

extension on File {
  Future<File> autoCreate() async {
    if (await exists()) {
      return this;
    }
    await parent.create(recursive: true);
    return create();
  }
}
