import 'package:rc/rc.dart';

import '../prisma_namespace.dart';
import 'prisma+config.dart';

extension Prisma$Environment on PrismaNamespace {
  bool get _skipDotiableKeys => envAsBoolean('prisma.env.skip_dotiable_keys');

  Map<String, String> get environment => config.toEnvironmentMap(skipDotiableKeys: _skipDotiableKeys);

  String? env(String name) => config.env(name);

  bool envAsBoolean(String name) {
    final value = config(name);
    return switch (value) {
      true || "on" || "true" || 1 || "1" => true,
      _ => false,
    };
  }
}
