import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day.dart';
import '../models/journal.dart';
import '../models/settings.dart';

/// Everything stays on the device in the app's private preferences.
class Store {
  static const _kSettings = 'settings.v1';
  static const _kInputs = 'inputs.v1';
  static const _kJournal = 'journal.v1';
  static const _kLastSync = 'lastSync.v1';

  final SharedPreferences _prefs;
  Store._(this._prefs);

  static Future<Store> open() async => Store._(await SharedPreferences.getInstance());

  UserSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return UserSettings();
    try {
      return UserSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('Wateen: bad settings: $e');
      return UserSettings();
    }
  }

  Future<void> saveSettings(UserSettings s) => _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  Map<String, DayInputs> loadInputs() {
    final raw = _prefs.getString(_kInputs);
    if (raw == null) return {};
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final out = <String, DayInputs>{};
      m.forEach((k, v) {
        try {
          out[k] = DayInputs.fromJson(Map<String, dynamic>.from(v as Map));
        } catch (e) {
          debugPrint('Wateen: skipping day $k: $e');
        }
      });
      return out;
    } catch (e) {
      debugPrint('Wateen: bad inputs cache: $e');
      return {};
    }
  }

  Future<void> saveInputs(Map<String, DayInputs> inputs) =>
      _prefs.setString(_kInputs, jsonEncode(inputs.map((k, v) => MapEntry(k, v.toJson()))));

  Map<String, JournalEntry> loadJournal() {
    final raw = _prefs.getString(_kJournal);
    if (raw == null) return {};
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return m.map((k, v) => MapEntry(k, JournalEntry.fromJson(Map<String, dynamic>.from(v as Map))));
    } catch (e) {
      debugPrint('Wateen: bad journal: $e');
      return {};
    }
  }

  Future<void> saveJournal(Map<String, JournalEntry> journal) =>
      _prefs.setString(_kJournal, jsonEncode(journal.map((k, v) => MapEntry(k, v.toJson()))));

  DateTime? loadLastSync() {
    final v = _prefs.getInt(_kLastSync);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> saveLastSync(DateTime t) => _prefs.setInt(_kLastSync, t.millisecondsSinceEpoch);

  Future<void> clearData() async {
    await _prefs.remove(_kInputs);
    await _prefs.remove(_kLastSync);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_kInputs);
    await _prefs.remove(_kLastSync);
    await _prefs.remove(_kJournal);
    await _prefs.remove(_kSettings);
  }
}
