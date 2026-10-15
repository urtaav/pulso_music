import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_handler.dart';
import '../data/library.dart';
import '../data/media_store.dart';
import '../data/settings.dart';
import '../data/song.dart';
import '../data/user_store.dart';

// Both are created in main() before the UI starts and injected here.
final userStoreProvider = Provider<UserStore>(
  (ref) => throw UnimplementedError('override in main'),
);
final audioHandlerProvider = Provider<PulsoAudioHandler>(
  (ref) => throw UnimplementedError('override in main'),
);

final mediaStoreProvider = Provider((ref) => const MediaStoreApi());

// ---- Ajustes ----

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(userStoreProvider).loadSettings();

  void update(Settings Function(Settings) change) {
    state = change(state);
    ref.read(userStoreProvider).saveSettings(state);
  }
}

// ---- Biblioteca ----

/// Raw MediaStore scan; refresh() scans again.
final scannedSongsProvider =
    AsyncNotifierProvider<ScannedSongsController, List<Song>>(
      ScannedSongsController.new,
      retry: (_, _) => null,
    );

class ScannedSongsController extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() => ref.read(mediaStoreProvider).scan();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(mediaStoreProvider).scan());
  }
}

final folderOverridesProvider =
    NotifierProvider<FolderOverridesController, Map<String, bool>>(
      FolderOverridesController.new,
    );

class FolderOverridesController extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() =>
      ref.read(userStoreProvider).loadFolderOverrides();

  void set(String folder, bool included) {
    state = {...state, folder: included};
    ref.read(userStoreProvider).saveFolderOverrides(state);
  }
}

final libraryProvider = Provider<AsyncValue<Library>>((ref) {
  final minDuration = ref.watch(settingsProvider.select((s) => s.minDuration));
  final overrides = ref.watch(folderOverridesProvider);
  return ref
      .watch(scannedSongsProvider)
      .whenData(
        (scanned) => Library.build(
          scanned: scanned,
          folderOverrides: overrides,
          minDuration: minDuration,
        ),
      );
});

/// Library or empty while loading; handy for screens that just list things.
final libraryValueProvider = Provider<Library>(
  (ref) => ref.watch(libraryProvider).value ?? Library.empty,
);

// ---- Favoritos, listas y recientes ----

final favoritesProvider = NotifierProvider<FavoritesController, Set<int>>(
  FavoritesController.new,
);

class FavoritesController extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.read(userStoreProvider).loadFavorites();

  void toggle(int songId) {
    state = state.contains(songId)
        ? ({...state}..remove(songId))
        : {...state, songId};
    ref.read(userStoreProvider).saveFavorites(state);
  }
}

final playlistsProvider = NotifierProvider<PlaylistsController, List<Playlist>>(
  PlaylistsController.new,
);

class PlaylistsController extends Notifier<List<Playlist>> {
  @override
  List<Playlist> build() => ref.read(userStoreProvider).loadPlaylists();

  Playlist create(String name) {
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      songIds: const [],
    );
    _save([...state, playlist]);
    return playlist;
  }

  void rename(String id, String name) =>
      _save([for (final p in state) p.id == id ? p.copyWith(name: name) : p]);

  void delete(String id) => _save(state.where((p) => p.id != id).toList());

  /// Returns false when the song was already in the playlist.
  bool addSong(String id, int songId) {
    final playlist = state.firstWhere((p) => p.id == id);
    if (playlist.songIds.contains(songId)) return false;
    _save([
      for (final p in state)
        p.id == id ? p.copyWith(songIds: [...p.songIds, songId]) : p,
    ]);
    return true;
  }

  void removeSongAt(String id, int index) => _save([
    for (final p in state)
      p.id == id ? p.copyWith(songIds: [...p.songIds]..removeAt(index)) : p,
  ]);

  void _save(List<Playlist> playlists) {
    state = playlists;
    ref.read(userStoreProvider).savePlaylists(playlists);
  }
}

final recentsProvider = NotifierProvider<RecentsController, List<int>>(
  RecentsController.new,
);

class RecentsController extends Notifier<List<int>> {
  @override
  List<int> build() {
    final handler = ref.read(audioHandlerProvider);
    final subscription = handler.songStarted.listen((song) {
      state = pushRecent(state, song.id);
      ref.read(userStoreProvider).saveRecents(state);
    });
    ref.onDispose(subscription.cancel);
    return ref.read(userStoreProvider).loadRecents();
  }
}

// ---- Reproducción ----

final mediaItemProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
);

final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
);

final queueProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(audioHandlerProvider).queue,
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioHandlerProvider).positionStream,
);

final isPlayingProvider = Provider<bool>(
  (ref) => ref.watch(playbackStateProvider).value?.playing ?? false,
);

final sleepTimerProvider = StreamProvider<SleepTimerState>((ref) async* {
  final handler = ref.watch(audioHandlerProvider);
  yield handler.sleepState;
  yield* handler.sleepStream;
});

final audioSessionIdProvider = StreamProvider<int?>(
  (ref) => ref.watch(audioHandlerProvider).audioSessionId,
);

/// Song currently loaded in the player, from the library.
final currentSongProvider = Provider<Song?>((ref) {
  final item = ref.watch(mediaItemProvider).value;
  final id = item?.extras?['songId'];
  if (id is! int) return null;
  return ref.watch(libraryValueProvider).byId(id) ??
      ref.read(audioHandlerProvider).currentSong;
});
