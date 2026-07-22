import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dart_orm/generator_helper.dart';
import 'package:dart_orm/version.dart';
import 'package:path/path.dart';

import 'src/generator.dart';
import 'src/download_engine.dart';

final _log = File('dart_orm_generator.log');

Future<void> _logMsg(String msg) async {
  await _log.writeAsString('$msg\n', mode: FileMode.append);
}

void main() async {
  await _log.writeAsString('=== Generator started at ${DateTime.now()} ===\n');

  // Use stdout so Prisma can read JSON-RPC responses
  final app = GeneratorApp.stdio(stdin: stdin, stdout: stdout);

  app.onManifest((config) async {
    await _logMsg('getManifest handler called');
    return _manifest(config);
  });

  app.onGenerate((options) async {
    await _logMsg('generate handler called');
    try {
      await _generate(options);
      await _logMsg('generate completed');
    } catch (e, st) {
      await _logMsg('generate ERROR: $e\n$st');
      rethrow;
    }
  });

  await _logMsg('Calling app.listen()...');
  await app.listen();
  await _logMsg('app.listen() returned, exiting');
}

Future<GeneratorManifest> _manifest(GeneratorConfig config) async {
  return GeneratorManifest(
    prettyName: 'Dart ORM',
    defaultOutput: 'generated_dart_client',
    version: 'v$version',
  );
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
