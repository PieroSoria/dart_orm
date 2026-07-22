import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dart_orm/generator_helper.dart';
import 'package:path/path.dart';

import 'src/generator.dart';
import 'src/download_engine.dart';

void main() async {
  final timer = Timer(const Duration(seconds: 30), () => exit(1));

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());

  await for (final line in lines) {
    if (line.trim().isEmpty) continue;

    Map request;
    try {
      request = jsonDecode(line) as Map;
    } catch (e) {
      continue;
    }

    final method = request['method'] as String?;
    final params = request['params'] as Map? ?? {};
    final id = request['id'];

    if (method == 'getManifest') {
      final manifest = GeneratorManifest(
        prettyName: 'Dart ORM',
        defaultOutput: 'generated_dart_client',
      );

      final response = jsonEncode({
        'jsonrpc': '2.0',
        'result': {'manifest': manifest.toJson()},
        'id': id,
      });

      stderr.writeln('\n$response');
      await stderr.flush();
    } else if (method == 'generate') {
      timer.cancel();
      try {
        final options = GeneratorOptions.fromJson(params);
        await _generate(options);

        final response = jsonEncode({
          'jsonrpc': '2.0',
          'result': null,
          'id': id,
        });

        stderr.writeln('\n$response');
        await stderr.flush();
        break;
      } catch (e) {
        final response = jsonEncode({
          'jsonrpc': '2.0',
          'error': {'code': -32000, 'message': e.toString()},
          'id': id,
        });
        stderr.writeln('\n$response');
        await stderr.flush();
      }
    }
  }

  timer.cancel();
}

Future<void> _generate(GeneratorOptions options) async {
  if (options.generator.output == null) {
    throw StateError('No output directory specified');
  }

  final generator = Generator(options);
  final libraries = generator.generate();
  final formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  for (final (filename, library) in libraries) {
    final emitter = DartEmitter.scoped(
      useNullSafetySyntax: true,
      orderDirectives: true,
    );
    final source = library.accept(emitter);
    final formated = formatter.format(source.toString());
    final output = await File(
      join(options.generator.output!.value, filename),
    ).autoCreate();
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
