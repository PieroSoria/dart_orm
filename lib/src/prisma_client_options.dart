import 'logging.dart';

enum ErrorFormat { pretty, colorless, minimal }

class PrismaClientOptions {
  final String? datasourceUrl;
  final Map<String, String>? datasources;
  final ErrorFormat errorFormat;
  LogEmitter logEmitter;

  PrismaClientOptions({this.datasourceUrl, this.datasources, required this.errorFormat, required this.logEmitter})
      : assert(!(datasourceUrl != null && datasources != null), 'DatasourceUrl and datasources cannot be used together');
}
