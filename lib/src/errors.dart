import '../version.dart';

abstract class PrismaClientError extends Error {
  final String message;
  final String clientVersion;

  PrismaClientError({required this.message, this.clientVersion = version});

  @override
  toString() => '$runtimeType: $message';
}

class PrismaClientValidationError extends PrismaClientError {
  PrismaClientValidationError({required super.message, super.clientVersion});
}

class PrismaClientUnknownRequestError extends PrismaClientError {
  PrismaClientUnknownRequestError({required super.message, super.clientVersion});
}

class PrismaClientRustPanicError extends PrismaClientError {
  PrismaClientRustPanicError({required super.message, super.clientVersion});
}

class PrismaClientInitializationError extends PrismaClientError {
  final String? errorCode;

  PrismaClientInitializationError({this.errorCode, required super.message, super.clientVersion});

  @override
  toString() => '$runtimeType: $errorCode $message';
}

class PrismaClientKnownRequestError extends PrismaClientError {
  final String code;
  final Map<String, dynamic>? meta;

  PrismaClientKnownRequestError({required this.code, required super.message, super.clientVersion, this.meta});

  @override
  toString() => '$runtimeType: $code $message';
}
