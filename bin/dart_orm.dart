import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:dart_orm/generator_helper.dart';
import 'package:dart_orm/version.dart';
import 'package:path/path.dart';

import 'src/generator.dart';
import 'src/utils/is_flutter_engine_type.dart';
import 'src/download_engine.dart';

void main() async {
  final app = GeneratorApp.stdio(stdin: stdin, stdout: stdout);
  app.onManifest(manifest);
  app.onGenerate((options) async {
    try {
      stderr.writeln('Generate started');
      await generate(options);
      stderr.writeln('Generate completed');
    } catch (e, st) {
      stderr.writeln('ERROR: $e');
      stderr.writeln('$st');
      rethrow;
    }
  });

  await app.listen();
  stderr.writeln('Server closed, exiting.');
}

Future<GeneratorManifest> manifest(GeneratorConfig config) async {
  final engines = switch (isFlutterEngineType(config.config)) {
    true => null,
    _ => const [EngineType.queryEngine]
  };

  return GeneratorManifest(
    prettyName: 'Dart ORM',
    defaultOutput: 'generated_dart_client',
    version: 'v$version',
    requiresEngines: engines,
  );
}

Future<void> generate(GeneratorOptions options) async {
  if (options.generator.output == null) {
    throw StateError('No output directory specified');
  }

  stderr.writeln('Generating Dart ORM client...');

  stderr.writeln('  Building generator...');
  final generator = Generator(options);
  stderr.writeln('  Calling generator.generate()...');
  final libraries = generator.generate();
  stderr.writeln('  Generate done, formatting...');

  final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  for (final (filename, library) in libraries) {
    stderr.writeln('  Writing $filename...');
    final emitter = DartEmitter.scoped(useNullSafetySyntax: true, orderDirectives: true);
    final source = library.accept(emitter);
    stderr.writeln('    source length: ${source.toString().length}');
    final formated = formatter.format(source.toString());
    stderr.writeln('    formatted length: ${formated.length}');
    final output = await File(join(options.generator.output!.value, filename)).autoCreate();
    stderr.writeln('    created file: ${output.path}');

    await output.writeAsString(formated);
    stderr.writeln('    written.');
  }

  stderr.writeln('Downloading query engine...');
  await downloadEngine(options);
  stderr.writeln('Done!');
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
