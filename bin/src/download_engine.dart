import 'dart:io';

import 'package:dart_orm/generator_helper.dart';
import 'package:path/path.dart' as path;

import 'utils/is_flutter_engine_type.dart';
import 'utils/iterable.dart';

Future<void> downloadEngine(GeneratorOptions options) async {
  if (isFlutterEngineType(options.generator.config)) {
    return;
  }

  if (options.noEngine) {
    print('ℹ️[orm] Engine download skipped (noEngine=true)');
    return;
  }

  // 1) Try Prisma-provided binary path first
  final sourcePath = options.binaryPaths.queryEngine?.values.firstOrNull;
  if (sourcePath != null) {
    final source = File(sourcePath);
    if (await source.exists()) {
      final target = _engineFile(options.schemaPath);
      if (await target.exists()) await target.delete();
      await source.copy(target.path);
      print('✅[orm] Query engine copied to ${target.path}');
      return;
    }
    print('⚠️[orm] Prisma provided the engine path, but the file does not exist');
  }

  // 2) Skip download if engine already exists
  final target = _engineFile(options.schemaPath);
  if (await target.exists() && await target.length() > 1000000) {
    return;
  }

  // 3) Download from Prisma CDN
  final version = options.version;
  if (version.isEmpty) {
    print("⚠️[orm] Engine version not provided in generate request.");
    return;
  }

  final nativeTarget = options.generator.binaryTargets
      .firstWhereOrNull((t) => t.native)
      ?.value;
  if (nativeTarget == null) {
    print("⚠️[orm] Cannot determine native binary target.");
    return;
  }

  final isWindows = nativeTarget == 'windows';
  final engineName = 'query-engine';
  final ext = isWindows ? '.exe.gz' : '.gz';
  final url = 'https://binaries.prisma.sh/all_commits/$version/$nativeTarget/$engineName$ext';

  print('ℹ️[orm] Downloading query engine ($nativeTarget)...');

  try {
    final client = HttpClient();
    client.userAgent = 'dart_orm';
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      print('⚠️[orm] Engine download failed: HTTP ${response.statusCode}');
      return;
    }

    final compressed = await response.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    final decompressed = gzip.decode(compressed);

    if (await target.exists()) await target.delete();
    await target.writeAsBytes(decompressed, flush: true);

    print('✅[orm] Query engine downloaded to ${target.path}');
  } catch (e) {
    print('⚠️[orm] Engine download error: $e');
  }
}

File _engineFile(String schemaPath) {
  final dir = path.dirname(schemaPath);
  return File(path.join(dir, 'prisma-query-engine'));
}
