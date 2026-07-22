import 'package:rc/rc.dart';

import '../prisma_namespace.dart';
import '_loader.dart' if (dart.library.io) '_loader.io.dart';

extension Prisma$Config on PrismaNamespace {
  static final _config = () {
    return RC(shouldWarn: true, loaders: {loader});
  }();

  RC get config => _config;
}
