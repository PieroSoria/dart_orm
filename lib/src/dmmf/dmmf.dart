import 'datamodel.dart';
import 'mappings.dart';
import 'schema.dart';

export 'datamodel.dart';
export 'mappings.dart';
export 'schema.dart';

class DMMF {
  final DataModel datamodel;
  final Schema schema;
  final Mappings mappings;
  final Map<String, dynamic> source;

  const DMMF({required this.datamodel, required this.schema, required this.mappings, required this.source});

  factory DMMF.fromJson(Map json) {
    return DMMF(
      datamodel: DataModel.fromJson(json['datamodel']),
      schema: Schema.fromJson(json['schema']),
      mappings: Mappings.fromJson(json['mappings']),
      source: json.cast(),
    );
  }
}
