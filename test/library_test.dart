import 'package:flutter_test/flutter_test.dart';
import 'package:pulso_music/core/format.dart';
import 'package:pulso_music/data/library.dart';
import 'package:pulso_music/data/settings.dart';
import 'package:pulso_music/data/song.dart';
import 'package:pulso_music/data/user_store.dart';

Song song(
  int id, {
  String title = 'canción',
  String artist = 'artista',
  String album = 'álbum',
  int albumId = 1,
  String folder = '/storage/emulated/0/Music',
  int seconds = 200,
  int added = 0,
  bool systemSound = false,
  bool recording = false,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: album,
    albumId: albumId,
    duration: Duration(seconds: seconds),
    path: '$folder/$id.mp3',
    folder: folder,
    dateAdded: DateTime(2026, 1, 1).add(Duration(days: added)),
    isSystemSound: systemSound,
    isRecording: recording,
  );
}

Library build(
  List<Song> songs, {
  Map<String, bool> overrides = const {},
  int minSeconds = 30,
}) => Library.build(
  scanned: songs,
  folderOverrides: overrides,
  minDuration: Duration(seconds: minSeconds),
);

void main() {
  group('isExcludedByDefault', () {
    test('excludes anything under WhatsApp', () {
      expect(
        isExcludedByDefault(
          '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
        ),
        isTrue,
      );
      expect(
        isExcludedByDefault(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/202641',
        ),
        isTrue,
      );
    });

    test('excludes recorder and system sound folders', () {
      for (final folder in [
        '/storage/emulated/0/Recordings',
        '/storage/emulated/0/Recordings/Call',
        '/storage/emulated/0/Notifications',
        '/storage/emulated/0/Ringtones',
        '/storage/emulated/0/Alarms',
        '/storage/emulated/0/Voice Recorder',
      ]) {
        expect(isExcludedByDefault(folder), isTrue, reason: folder);
      }
    });

    test('keeps music folders, even with similar words inside names', () {
      expect(isExcludedByDefault('/storage/emulated/0/Music'), isFalse);
      expect(
        isExcludedByDefault('/storage/emulated/0/Download/Callejeros'),
        isFalse,
      );
      expect(
        isExcludedByDefault('/storage/emulated/0/Music/Recordings of Bach'),
        isFalse,
      );
    });

    test('excludes folders where most files are flagged', () {
      expect(isExcludedByDefault('/x/Media', mostlyFlagged: true), isTrue);
    });
  });

  group('Library.build', () {
    const music = '/storage/emulated/0/Music';
    const whatsapp = '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio';

    test('drops excluded folders and short audios', () {
      final library = build([
        song(1, folder: music),
        song(2, folder: whatsapp),
        song(3, folder: music, seconds: 10),
      ]);
      expect(library.songs.map((s) => s.id), [1]);
    });

    test('lists every folder with its state', () {
      final library = build([
        song(1, folder: music),
        song(2, folder: whatsapp),
      ]);
      final byPath = {for (final f in library.folders) f.path: f};
      expect(byPath[music]!.included, isTrue);
      expect(byPath[whatsapp]!.included, isFalse);
      expect(byPath[whatsapp]!.excludedByDefault, isTrue);
    });

    test('user overrides win over the defaults', () {
      final library = build(
        [song(1, folder: music), song(2, folder: whatsapp)],
        overrides: {music: false, whatsapp: true},
      );
      expect(library.songs.map((s) => s.id), [2]);
    });

    test('a ringtone inside Music is dropped without excluding the folder', () {
      final library = build([
        song(1, folder: music),
        song(2, folder: music),
        song(3, folder: music, systemSound: true),
      ]);
      expect(library.songs.map((s) => s.id), unorderedEquals([1, 2]));
      expect(library.folders.single.included, isTrue);
    });

    test('flagged files come back when the folder is explicitly included', () {
      final library = build(
        [song(1, folder: music), song(2, folder: music, recording: true)],
        overrides: {music: true},
      );
      expect(library.songs, hasLength(2));
    });

    test('a folder of mostly recordings is excluded by default', () {
      const recorder = '/storage/emulated/0/Sounds/Grabadora';
      final library = build([
        song(1, folder: recorder, recording: true),
        song(2, folder: recorder, recording: true),
        song(3, folder: recorder),
      ]);
      expect(library.songs, isEmpty);
    });

    test('a zero minimum duration keeps everything', () {
      final library = build([song(1, seconds: 3)], minSeconds: 0);
      expect(library.songs, hasLength(1));
    });

    test('groups albums and artists', () {
      final library = build([
        song(1, album: 'B', albumId: 2, artist: 'Zoé'),
        song(2, album: 'A', albumId: 1, artist: 'Café Tacvba'),
        song(3, album: 'A', albumId: 1, artist: 'Café Tacvba'),
      ]);
      expect(library.albums.map((a) => a.title), ['A', 'B']);
      expect(library.albums.first.songs, hasLength(2));
      expect(library.artists.map((a) => a.name), ['Café Tacvba', 'Zoé']);
    });

    test('resolve keeps order and skips missing songs', () {
      final library = build([song(1), song(2), song(3)]);
      expect(library.resolve([3, 99, 1]).map((s) => s.id), [3, 1]);
    });

    test('recently added is newest first', () {
      final library = build([
        song(1, added: 1),
        song(2, added: 5),
        song(3, added: 3),
      ]);
      expect(library.recentlyAdded.map((s) => s.id), [2, 3, 1]);
    });
  });

  group('search and sort', () {
    final songs = [
      song(1, title: 'Canción de amor', artist: 'Natalia Lafourcade'),
      song(2, title: 'Eres', artist: 'Café Tacvba', album: 'Cuatro Caminos'),
      song(3, title: 'Labios rotos', artist: 'Zoé'),
    ];

    test('ignores accents and case', () {
      expect(searchSongs(songs, 'cancion').map((s) => s.id), [1]);
      expect(searchSongs(songs, 'CAFE').map((s) => s.id), [2]);
      expect(searchSongs(songs, 'zoe').map((s) => s.id), [3]);
    });

    test('matches the album and returns nothing for a blank query', () {
      expect(searchSongs(songs, 'caminos').map((s) => s.id), [2]);
      expect(searchSongs(songs, '   '), isEmpty);
    });

    test('sorts by artist and by duration', () {
      expect(SongSort.artist.apply(songs).map((s) => s.id), [2, 1, 3]);
      final timed = [song(1, seconds: 100), song(2, seconds: 300)];
      expect(SongSort.duration.apply(timed).map((s) => s.id), [2, 1]);
    });
  });

  group('persistence', () {
    test('recents move to the front without duplicates', () {
      expect(pushRecent([3, 2, 1], 1), [1, 3, 2]);
      final many = List.generate(UserStore.maxRecents, (i) => i);
      expect(pushRecent(many, 100), hasLength(UserStore.maxRecents));
    });

    test('settings survive a JSON round trip', () {
      const original = Settings(
        minDurationSeconds: 45,
        accent: 0xFFFF5C6C,
        visualizerStyle: VisualizerStyle.wave,
        visualizerIntensity: 0.4,
        widgetOpacity: 0.6,
      );
      final restored = Settings.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
    });

    test('settings fall back on bad values', () {
      final restored = Settings.fromJson({
        'visualizerStyle': 'laser',
        'visualizerIntensity': 9,
        'minDurationSeconds': 'mucho',
      });
      expect(restored.visualizerStyle, VisualizerStyle.bars);
      expect(restored.visualizerIntensity, 1);
      expect(restored.minDurationSeconds, 30);
    });

    test('playlists and sessions round trip', () {
      const playlist = Playlist(id: 'a', name: 'Correr', songIds: [3, 1]);
      final restored = Playlist.fromJson(playlist.toJson())!;
      expect(restored.name, 'Correr');
      expect(restored.songIds, [3, 1]);

      const session = PlaybackSession(
        songIds: [1, 2],
        index: 1,
        position: Duration(seconds: 42),
        shuffle: true,
        repeat: 2,
      );
      final back = PlaybackSession.fromJson(session.toJson())!;
      expect(back.index, 1);
      expect(back.position, const Duration(seconds: 42));
      expect(back.shuffle, isTrue);
      expect(back.repeat, 2);
      expect(PlaybackSession.fromJson('basura'), isNull);
    });
  });

  group('format', () {
    test('durations', () {
      expect(formatDuration(const Duration(seconds: 187)), '3:07');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1:02:05',
      );
      expect(formatTotal(const Duration(minutes: 125)), '2 h 05 min');
      expect(songCount(1), '1 canción');
    });

    test('greeting follows the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 9)), 'Buenos días');
      expect(greetingFor(DateTime(2026, 1, 1, 15)), 'Buenas tardes');
      expect(greetingFor(DateTime(2026, 1, 1, 22)), 'Buenas noches');
    });
  });

  test('Song.fromMap fills gaps from the file name', () {
    final s = Song.fromMap({
      'id': 7,
      'title': '',
      'artist': null,
      'path': '/storage/emulated/0/Music/mi rola.mp3',
      'folder': '/storage/emulated/0/Music',
      'durationMs': 1000,
      'dateAdded': 0,
    });
    expect(s.title, 'mi rola');
    expect(s.artist, 'Artista desconocido');
    expect(s.uri, 'content://media/external/audio/media/7');
    expect(s.folderName, 'Music');
  });
}
