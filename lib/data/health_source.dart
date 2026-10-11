import '../models/raw.dart';

enum ConnectStatus { connected, needsHealthConnect, needsHealthConnectUpdate, denied, unsupported }

abstract class HealthSource {
  /// Asks for read access. Safe to call repeatedly.
  Future<ConnectStatus> connect();

  /// Reads everything needed for scoring between [start] and [end].
  Future<RawBundle> fetch(DateTime start, DateTime end);
}
