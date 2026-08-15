import 'dart:io';

import 'package:dart_orm/generator_helper.dart';

import 'bin/src/generator.dart';

void main() {
  stderr.writeln('=== Test Generator Start ===');

  try {
    stderr.writeln('Creating minimal DMMF JSON...');

    final dmmfJson = {
      'datamodel': {
        'models': <Map<String, dynamic>>[],
        'enums': <Map<String, dynamic>>[],
        'types': <Map<String, dynamic>>[],
      },
      'schema': {
        'inputObjectTypes': {'model': <Map<String, dynamic>>[], 'prisma': <Map<String, dynamic>>[]},
        'outputObjectTypes': {'model': <Map<String, dynamic>>[], 'prisma': <Map<String, dynamic>>[]},
        'enumTypes': {'model': <Map<String, dynamic>>[], 'prisma': <Map<String, dynamic>>[]},
        'fieldRefTypes': {'model': <Map<String, dynamic>>[], 'prisma': <Map<String, dynamic>>[]},
      },
      'mappings': {
        'modelOperations': <Map<String, dynamic>>[],
        'otherOperations': {
          'read': <String>[],
          'write': <String>[],
        },
      },
    };
    stderr.writeln('DMMF JSON created');

    final optionsJson = {
      'generator': {
        'name': 'dart_orm',
        'output': {'value': Directory.systemTemp.path},
        'isCustomOutput': true,
        'provider': {'value': 'dart_orm'},
        'config': <String, dynamic>{},
        'binaryTargets': <Map<String, dynamic>>[],
        'previewFeatures': <String>[],
      },
      'otherGenerators': <Map<String, dynamic>>[],
      'schemaPath': Directory.systemTemp.path,
      'schema': '',
      'dmmf': dmmfJson,
      'datasources': <Map<String, dynamic>>[
        {
          'name': 'db',
          'provider': 'postgresql',
          'activeProvider': 'postgresql',
          'url': {'value': 'postgresql://localhost:5432/test'},
          'schemas': <String>[],
        },
      ],
      'version': 'test',
      'binaryPaths': {},
      'postinstall': false,
      'noEngine': true,
    };

    stderr.writeln('Creating GeneratorOptions...');
    final options = GeneratorOptions.fromJson(optionsJson);
    stderr.writeln('GeneratorOptions created successfully');

    stderr.writeln('Creating Generator...');
    final generator = Generator(options);
    stderr.writeln('Generator created successfully');

    stderr.writeln('Calling generator.generate()...');
    final libraries = generator.generate();
    stderr.writeln('Generate returned ${libraries.length} libraries:');
    for (final (filename, library) in libraries) {
      stderr.writeln('  - $filename');
    }

    stderr.writeln('');
    stderr.writeln('=== Success! Generator works with minimal DMMF ===');
    print('SUCCESS: Generator ran with empty datamodel');
  } catch (e, st) {
    stderr.writeln('ERROR: $e');
    stderr.writeln('STACK: $st');
    print('FAILED: $e');
  }

  stderr.writeln('=== Test Generator End ===');
}
