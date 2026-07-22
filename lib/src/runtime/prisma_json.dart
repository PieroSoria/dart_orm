import 'package:dart_orm/dart_orm.dart';

class PrismaJson implements JsonConvertible<Object> {
  final Object value;

  const PrismaJson(this.value);
  const PrismaJson.fromJson(this.value);

  @override
  Object toJson() => value;
}
