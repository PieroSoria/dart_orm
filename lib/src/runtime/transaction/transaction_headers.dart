import 'package:oxy/oxy.dart';

class TransactionHeaders {
  final _headers = Headers();

  TransactionHeaders({String? traceparent}) {
    if (traceparent != null) {
      _headers.set('traceparent', traceparent);
    }
  }

  Headers get headers => _headers;

  void append(String name, String value) {
    if (name.toLowerCase() == 'traceparent') {
      return _headers.set(name, value);
    }
    _headers.append(name, value);
  }

  void delete(String name) => _headers.delete(name);

  String? get(String name) => _headers.get(name);

  bool has(String name) => _headers.has(name);

  void set(String name, String value) => _headers.set(name, value);

  String? get traceparent => _headers.get('traceparent');

  set traceparent(String? value) {
    if (value == null || value.isEmpty) {
      return _headers.delete('traceparent');
    }
    _headers.set('traceparent', value);
  }
}
