import 'dart:typed_data';

abstract interface class JsonConvertible<T> {
  T toJson();

  static serialize(value) {
    return switch (value) {
      JsonConvertible value => serialize(value.toJson()),
      Uint8List bytes => bytes,
      TypedData bytes => bytes,
      Map values => values.map((key, value) => MapEntry(key, serialize(value))),
      Iterable values => values.map((e) => serialize(e)).toList(),
      _ => value,
    };
  }
}
