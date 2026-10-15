import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'listening_stats.dart';
import 'settings.dart';

/// Everything the user creates or chooses, stored as JSON in
/// SharedPreferences. The library itself is never stored: it comes from
/// MediaStore on every scan.
class UserStore {
  UserStore(this._prefs);

  final SharedPreferences _prefs;

  static const _settings = 'settings';
  static const _favorites = 'favorites';
  static const _playlists = 'playlists';
  static const _folders = 'folder_overrides';
  static const _recents = 'recently_played';
  static const _session = 'session';
  static const _shuffle = 'shuffle_history';
  static const _stats = 'listening_stats';

  static const maxRecents = 30;

  Object? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null; // Datos dañados: se vuelve a los valores por defecto.
    }
  }

  Future<void> _write(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  Settings loadSettings() {
    final json = _read(_settings);
    return json is Map<String, Object?>
        ? Settings.fromJson(json)
        : const Settings();
  }

  Future<void> saveSettings(Settings settings) =>
      _write(_settings, settings.toJson());

  Set<int> loadFavorites() {
    final json = _read(_favorites);
    return json is List ? json.whereType<int>().toSet() : {};
  }

  Future<void> saveFavorites(Set<int> ids) => _write(_favorites, ids.toList());

  List<Playlist> loadPlaylists() {
    final json = _read(_playlists);
    if (json is! List) return [];
    return [for (final item in json) ?Playlist.fromJson(item)];
  }

  Future<void> savePlaylists(List<Playlist> playlists) =>
      _write(_playlists, [for (final p in playlists) p.toJson()]);

  /// Only folders the user toggled; the rest follow the default rules.
  Map<String, bool> loadFolderOverrides() {
    final json = _read(_folders);
    if (json is! Map<String, Object?>) return {};
    return {
      for (final entry in json.entries)
        if (entry.value is bool) entry.key: entry.value! as bool,
    };
  }

  Future<void> saveFolderOverrides(Map<String, bool> overrides) =>
      _write(_folders, overrides);

  List<int> loadRecents() {
    final json = _read(_recents);
    return json is List ? json.whereType<int>().toList() : [];
  }

  Future<void> saveRecents(List<int> ids) => _write(_recents, ids);

  PlaybackSession? loadSession() => PlaybackSession.fromJson(_read(_session));

  Future<void> saveSession(PlaybackSession session) =>
      _write(_session, session.toJson());

  Set<int> loadShuffleHistory() {
    final json = _read(_shuffle);
    return json is List ? json.whereType<int>().toSet() : {};
  }

  Future<void> saveShuffleHistory(Set<int> played) =>
      _write(_shuffle, played.toList());

  ListeningStats loadStats() => ListeningStats.fromJson(_read(_stats));

  Future<void> saveStats(ListeningStats stats) =>
      _write(_stats, stats.toJson());
}

/// Moves [id] to the front, without duplicates, capped at [UserStore.maxRecents].
List<int> pushRecent(List<int> recents, int id) =>
    [id, ...recents.where((r) => r != id)].take(UserStore.maxRecents).toList();
