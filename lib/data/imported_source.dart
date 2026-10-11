import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/raw.dart';
import '../util/clock.dart';
import 'health_source.dart';
import 'import_format.dart';

/// Keeps the imported file in the app's private storage.
class ImportStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}imported-data.json');
  }

  static Future<String?> read() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  static Future<void> write(String text) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(text, flush: true);
  }

  static Future<void> delete() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}

/// Serves samples from an imported Wateen data file.
class ImportedHealthSource implements HealthSource {
  ImportedData? _data;
  DateTime? _parsedAt;

  /// Parses the stored file; re-parsed every few minutes so date alignment
  /// follows the clock.
  Future<ImportedData?> load() async {
    final now = clockNow();
    if (_data != null && _parsedAt != null && now.difference(_parsedAt!).abs() < const Duration(minutes: 10)) {
      return _data;
    }
    final text = await ImportStore.read();
    if (text == null) {
      _data = null;
      return null;
    }
    _data = ImportedData.parse(text, now: now);
    _parsedAt = now;
    return _data;
  }

  void clearCache() {
    _data = null;
    _parsedAt = null;
  }

  @override
  Future<ConnectStatus> connect() async => (await load()) == null ? ConnectStatus.denied : ConnectStatus.connected;

  @override
  Future<RawBundle> fetch(DateTime start, DateTime end) async {
    final data = await load();
    if (data == null) return RawBundle(start: start, end: end, missing: ['IMPORT_FILE']);
    return data.slice(start, end);
  }
}
