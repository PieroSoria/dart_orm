import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';

class DartCodegen {
  final DartFormatter _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );
  late final String _outputDir;

  Future<void> generate(Map<String, dynamic> params) async {
    final generator = params['generator'] as Map<String, dynamic>;
    final dmmf = params['dmmf'] as Map<String, dynamic>;
    final datamodel = dmmf['datamodel'] as Map<String, dynamic>;

    final outputConfig = generator['output'] as Map<String, dynamic>?;
    final outputValue = outputConfig?['value'] as String? ?? '../lib/orm';
    _outputDir = p.normalize(p.join(p.current, outputValue));

    await Directory(_outputDir).create(recursive: true);

    final models = datamodel['models'] as List<dynamic>? ?? [];
    final enums = datamodel['enums'] as List<dynamic>? ?? [];
    final compositeTypes = datamodel['types'] as List<dynamic>? ?? [];

    for (final enumDef in enums) {
      final (name, content) = _generateEnum(enumDef as Map<String, dynamic>);
      await _writeFile(name, content);
    }

    for (final model in [...models, ...compositeTypes]) {
      final (name, content) = _generateModel(
        model as Map<String, dynamic>,
        models.cast<Map<String, dynamic>>(),
      );
      await _writeFile(name, content);
    }

    {
      final (name, content) = _generateClient(
        models.cast<Map<String, dynamic>>(),
      );
      await _writeFile(name, content);
    }
  }

  Future<void> _writeFile(String filename, String content) async {
    final path = p.join(_outputDir, filename);
    try {
      await File(path).writeAsString(_formatter.format(content));
    } catch (_) {
      await File(path).writeAsString(content);
    }
  }

  String _resolveDartType(Map<String, dynamic> field) {
    final type = field['type'] as String;
    final kind = field['kind'] as String? ?? 'scalar';
    final isList = field['isList'] as bool? ?? false;
    final isRequired = field['isRequired'] as bool? ?? false;

    String base;
    if (kind == 'object' || kind == 'enum') {
      base = type.pascalCase;
    } else {
      base = switch (type) {
        'String' => 'String',
        'Int' => 'int',
        'Float' => 'double',
        'BigInt' => 'BigInt',
        'Boolean' => 'bool',
        'DateTime' => 'DateTime',
        'Json' => 'Map<String, dynamic>',
        'Decimal' => 'Decimal',
        'Bytes' => 'List<int>',
        _ => type,
      };
    }

    if (isList) base = 'List<$base>';
    if (!isRequired && !isList) base = '$base?';
    return base;
  }

  (String, String) _generateEnum(Map<String, dynamic> enumDef) {
    final name = enumDef['name'] as String;
    final values = (enumDef['values'] as List<dynamic>)
        .map((v) => (v as Map<String, dynamic>)['name'] as String)
        .toList();

    final buf = StringBuffer();
    buf.writeln("import 'package:decimal/decimal.dart';");
    buf.writeln();
    if (enumDef['documentation'] case final doc?) buf.writeln('/// $doc');
    buf.writeln('enum $name {');
    for (final v in values) {
      buf.writeln('  ${v.pascalCase},');
    }
    buf.writeln();
    buf.writeln('  static $name? fromJson(dynamic value) {');
    buf.writeln('    if (value == null) return null;');
    buf.writeln(
      '    final str = value is Map ? value[\'value\'] as String : value as String;',
    );
    buf.writeln('    return $name.values.firstWhere((e) => e.name == str);');
    buf.writeln('  }');
    buf.writeln();
    buf.writeln('  String toJson() => name;');
    buf.writeln('}');

    return ('${name.snakeCase}.dart', buf.toString());
  }

  (String, String) _generateModel(
    Map<String, dynamic> model,
    List<Map<String, dynamic>> allModels,
  ) {
    final name = model['name'] as String;
    final fields = model['fields'] as List<dynamic>? ?? [];
    final buf = StringBuffer();
    final imports = <String>{"import 'prisma_client.dart';"};

    for (final field in fields) {
      final f = field as Map<String, dynamic>;
      final kind = f['kind'] as String? ?? 'scalar';
      final type = f['type'] as String;
      if (kind == 'object' || kind == 'enum') {
        imports.add("import '${type.snakeCase}.dart';");
      }
      if (type == 'Decimal') {
        imports.add("import 'package:decimal/decimal.dart';");
      }
    }

    for (final imp in imports) {
      buf.writeln(imp);
    }
    buf.writeln();

    if (model['documentation'] case final doc?) buf.writeln('/// $doc');
    buf.writeln('class $name {');

    for (final field in fields) {
      final f = field as Map<String, dynamic>;
      buf.writeln('  final ${_resolveDartType(f)} ${f['name']};');
    }

    buf.writeln();
    buf.writeln('  const $name({');
    for (final field in fields) {
      final f = field as Map<String, dynamic>;
      final req = f['isRequired'] as bool? ?? false;
      final list = f['isList'] as bool? ?? false;
      if (req && !list) {
        buf.writeln('    required this.${f['name']},');
      } else {
        buf.writeln('    this.${f['name']},');
      }
    }
    buf.writeln('  });');

    buf.writeln();
    buf.writeln('  factory $name.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('    $name(');
    for (final field in fields) {
      final f = field as Map<String, dynamic>;
      final fn = f['name'] as String;
      final kind = f['kind'] as String? ?? 'scalar';
      final list = f['isList'] as bool? ?? false;
      final type = f['type'] as String;

      if (kind == 'object') {
        if (list) {
          buf.writeln(
            "      $fn: (json['$fn'] as List<dynamic>?)?.map((e) => ${type.pascalCase}.fromJson(e as Map<String, dynamic>)).toList(),",
          );
        } else {
          buf.writeln(
            "      $fn: json['$fn'] != null ? ${type.pascalCase}.fromJson(json['$fn'] as Map<String, dynamic>) : null,",
          );
        }
      } else if (kind == 'enum') {
        buf.writeln("      $fn: ${type.pascalCase}.fromJson(json['$fn']),");
      } else if (['DateTime', 'BigInt', 'Decimal'].contains(type)) {
        buf.writeln("      $fn: _parse${type}(json['$fn']),");
      } else if (type == 'Bytes') {
        buf.writeln("      $fn: (json['$fn'] as List<dynamic>?)?.cast<int>(),");
      } else if (type == 'Json') {
        buf.writeln("      $fn: json['$fn'] as Map<String, dynamic>?,");
      } else {
        buf.writeln("      $fn: json['$fn'] as ${_resolveDartType(f)}?,");
      }
    }
    buf.writeln('    );');

    buf.writeln();
    buf.writeln('  Map<String, dynamic> toJson() => {');
    for (final field in fields) {
      final f = field as Map<String, dynamic>;
      final fn = f['name'] as String;
      final kind = f['kind'] as String? ?? 'scalar';
      final list = f['isList'] as bool? ?? false;
      final type = f['type'] as String;

      if (kind == 'object') {
        if (list) {
          buf.writeln("    '$fn': $fn?.map((e) => e.toJson()).toList(),");
        } else {
          buf.writeln("    '$fn': $fn?.toJson(),");
        }
      } else if (kind == 'enum' ||
          type == 'DateTime' ||
          type == 'BigInt' ||
          type == 'Decimal') {
        buf.writeln("    '$fn': $fn?.toJson(),");
      } else {
        buf.writeln("    '$fn': $fn,");
      }
    }
    buf.writeln('  };');
    buf.writeln('}');

    return ('${name.snakeCase}.dart', buf.toString());
  }

  (String, String) _generateClient(List<Map<String, dynamic>> models) {
    final buf = StringBuffer();
    buf.writeln("import 'dart:convert';");
    buf.writeln("import 'package:decimal/decimal.dart';");
    buf.writeln("import 'package:dart_orm/src/engine.dart';");

    for (final model in models) {
      buf.writeln("import '${(model['name'] as String).snakeCase}.dart';");
    }

    buf.writeln();
    buf.writeln('// ---- JSON protocol helpers ----');
    buf.writeln();

    buf.writeln('DateTime? _parseDateTime(dynamic v) {');
    buf.writeln("  if (v is String) return DateTime.parse(v);");
    buf.writeln(
      "  if (v is Map && v['\$type'] == 'DateTime') return DateTime.parse(v['value'] as String);",
    );
    buf.writeln('  return null;');
    buf.writeln('}');
    buf.writeln();

    buf.writeln('BigInt? _parseBigInt(dynamic v) {');
    buf.writeln("  if (v is int) return BigInt.from(v);");
    buf.writeln("  if (v is String) return BigInt.parse(v);");
    buf.writeln(
      "  if (v is Map && v['\$type'] == 'BigInt') return BigInt.parse(v['value'] as String);",
    );
    buf.writeln('  return null;');
    buf.writeln('}');
    buf.writeln();

    buf.writeln('Decimal? _parseDecimal(dynamic v) {');
    buf.writeln("  if (v is String) return Decimal.parse(v);");
    buf.writeln(
      "  if (v is Map && v['\$type'] == 'Decimal') return Decimal.parse(v['value'] as String);",
    );
    buf.writeln('  return null;');
    buf.writeln('}');
    buf.writeln();

    buf.writeln('extension _DateTimeX on DateTime {');
    buf.writeln("  String toJson() => toIso8601String();");
    buf.writeln('}');
    buf.writeln();
    buf.writeln('extension _BigIntX on BigInt {');
    buf.writeln("  String toJson() => toString();");
    buf.writeln('}');
    buf.writeln();
    buf.writeln('extension _DecimalX on Decimal {');
    buf.writeln("  String toJson() => toString();");
    buf.writeln('}');

    buf.writeln();
    buf.writeln('class PrismaClient {');
    buf.writeln('  final DartEngine _engine;');
    buf.writeln('  PrismaClient(this._engine);');
    buf.writeln();

    for (final model in models) {
      final name = model['name'] as String;
      buf.writeln(
        '  late final ${name}Delegate ${name.camelCase} = ${name}Delegate(_engine);',
      );
    }

    buf.writeln('}');

    for (final model in models) {
      final name = model['name'] as String;
      final fields = model['fields'] as List<dynamic>? ?? [];
      final scalarFields = fields
          .cast<Map<String, dynamic>>()
          .where((f) => (f['kind'] as String?) != 'object')
          .map((f) => f['name'] as String)
          .toList();

      buf.writeln();
      buf.writeln('class ${name}Delegate {');
      buf.writeln('  final DartEngine _engine;');
      buf.writeln('  const ${name}Delegate(this._engine);');
      buf.writeln();

      // findMany
      buf.writeln('  Future<List<$name>> findMany({');
      buf.writeln('    Map<String, dynamic>? where,');
      buf.writeln('    Map<String, dynamic>? orderBy,');
      buf.writeln('    int? take,');
      buf.writeln('    int? skip,');
      buf.writeln('    List<$name>? include,');
      buf.writeln('  }) async {');
      buf.writeln('    final result = await _engine.query({');
      buf.writeln("      'modelName': '$name',");
      buf.writeln("      'action': 'findMany',");
      buf.writeln("      'query': {");
      buf.writeln("        'arguments': {");
      buf.writeln("          if (where != null) 'where': where,");
      buf.writeln("          if (orderBy != null) 'orderBy': orderBy,");
      buf.writeln("          if (take != null) 'take': take,");
      buf.writeln("          if (skip != null) 'skip': skip,");
      buf.writeln('        },');

      buf.writeln("        'selection': {");
      for (final f in scalarFields) {
        buf.writeln("          '$f': true,");
      }
      buf.writeln('        },');

      buf.writeln('      },');
      buf.writeln('    });');
      buf.writeln(
        "    return (result['data'] as List? ?? result as List?)?.cast<Map<String, dynamic>>().map($name.fromJson).toList();",
      );
      buf.writeln('  }');

      // create
      buf.writeln();
      buf.writeln(
        '  Future<$name> create({required Map<String, dynamic> data}) async {',
      );
      buf.writeln('    final result = await _engine.query({');
      buf.writeln("      'modelName': '$name',");
      buf.writeln("      'action': 'create',");
      buf.writeln("      'query': {'arguments': {'data': data}},");
      buf.writeln('    });');
      buf.writeln(
        "    return $name.fromJson((result['data'] ?? result) as Map<String, dynamic>);",
      );
      buf.writeln('  }');

      // update
      buf.writeln();
      buf.writeln(
        '  Future<$name> update({required Map<String, dynamic> where, required Map<String, dynamic> data}) async {',
      );
      buf.writeln('    final result = await _engine.query({');
      buf.writeln("      'modelName': '$name',");
      buf.writeln("      'action': 'update',");
      buf.writeln(
        "      'query': {'arguments': {'where': where, 'data': data}},",
      );
      buf.writeln('    });');
      buf.writeln(
        "    return $name.fromJson((result['data'] ?? result) as Map<String, dynamic>);",
      );
      buf.writeln('  }');

      // delete
      buf.writeln();
      buf.writeln(
        '  Future<$name> delete({required Map<String, dynamic> where}) async {',
      );
      buf.writeln('    final result = await _engine.query({');
      buf.writeln("      'modelName': '$name',");
      buf.writeln("      'action': 'delete',");
      buf.writeln("      'query': {'arguments': {'where': where}},");
      buf.writeln('    });');
      buf.writeln(
        "    return $name.fromJson((result['data'] ?? result) as Map<String, dynamic>);",
      );
      buf.writeln('  }');

      buf.writeln('}');
    }

    return ('prisma_client.dart', buf.toString());
  }
}
