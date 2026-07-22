import 'dart:async';

import '../datasources/datasources.dart';
import '../prisma_client_options.dart';
import 'json_protocol/protocol.dart';
import 'metrics/metrics_format.dart';
import 'transaction/isolation_level.dart';
import 'transaction/transaction_headers.dart';
import 'transaction/transaction.dart';

abstract class Engine {
  final String schema;
  final Datasources datasources;
  final PrismaClientOptions options;

  const Engine({required this.options, required this.schema, required this.datasources});

  Future<void> start();
  Future<void> stop();

  Future<Map> request(JsonQuery query, {TransactionHeaders? headers, Transaction? transaction});

  Future<Transaction> startTransaction({required TransactionHeaders headers, int maxWait = 2000, int timeout = 5000, TransactionIsolationLevel? isolationLevel});

  Future<void> commitTransaction({required TransactionHeaders headers, required Transaction transaction});

  Future<void> rollbackTransaction({required TransactionHeaders headers, required Transaction transaction});

  Future<dynamic> metrics({Map<String, String>? globalLabels, required MetricsFormat format});
}
