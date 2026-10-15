import 'song.dart';

// Carpetas que casi nunca son música: se excluyen por defecto, pero el usuario
// puede volver a incluirlas desde Ajustes > Carpetas.
const _excludedSegments = {
  'notifications',
  'ringtones',
  'alarms',
  'recordings',
  'recorder',
  'voice recorder',
  'voicerecorder',
  'voice notes',
  'voicenotes',
  'call',
  'calls',
  'call recordings',
  'callrecordings',
  'callrecord',
  'sounds',
  'audiorecorder',
};

/// Whether a folder is excluded until the user says otherwise.
///
/// Any path with "WhatsApp" is out (audios and voice notes), as well as known
/// system/recorder folders and folders where Android flagged most files as
/// ringtones, notifications, alarms or recordings.
bool isExcludedByDefault(String folder, {bool mostlyFlagged = false}) {
  final lower = folder.toLowerCase();
  if (lower.contains('whatsapp')) return true;
  if (mostlyFlagged) return true;
  return lower.split('/').any(_excludedSegments.contains);
}

bool _isFlagged(Song song) => song.isSystemSound || song.isRecording;

class FolderInfo {
  const FolderInfo({
    required this.path,
    required this.songCount,
    required this.included,
    required this.excludedByDefault,
  });

  final String path;
  final int songCount;
  final bool included;
  final bool excludedByDefault;

  String get name => folderLabel(path);
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.songs,
  });

  final int id;
  final String title;
  final String artist;
  final List<Song> songs;
}

class Artist {
  const Artist({required this.name, required this.songs});

  final String name;
  final List<Song> songs;

  int get albumCount => songs.map((s) => s.albumId).toSet().length;
}

/// Library after applying folder exclusions and the minimum duration.
class Library {
  Library._({
    required this.songs,
    required this.folders,
    required this.albums,
    required this.artists,
  }) : _byId = {for (final s in songs) s.id: s};

  factory Library.build({
    required List<Song> scanned,
    required Map<String, bool> folderOverrides,
    required Duration minDuration,
  }) {
    final byFolder = <String, List<Song>>{};
    for (final song in scanned) {
      byFolder.putIfAbsent(song.folder, () => []).add(song);
    }

    final folders = <FolderInfo>[];
    final included = <String>{};
    for (final entry in byFolder.entries) {
      final flagged = entry.value.where(_isFlagged).length;
      final byDefault = isExcludedByDefault(
        entry.key,
        mostlyFlagged: flagged * 2 > entry.value.length,
      );
      final isIncluded = folderOverrides[entry.key] ?? !byDefault;
      if (isIncluded) included.add(entry.key);
      folders.add(
        FolderInfo(
          path: entry.key,
          songCount: entry.value.length,
          included: isIncluded,
          excludedByDefault: byDefault,
        ),
      );
    }
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    // A ringtone or recording sitting in a music folder is still left out,
    // unless the user explicitly included that folder.
    bool keep(Song song) =>
        included.contains(song.folder) &&
        song.duration >= minDuration &&
        (!_isFlagged(song) || folderOverrides[song.folder] == true);

    final songs = scanned.where(keep).toList()..sort(compareByTitle);

    return Library._(
      songs: songs,
      folders: folders,
      albums: _groupAlbums(songs),
      artists: _groupArtists(songs),
    );
  }

  static final empty = Library.build(
    scanned: const [],
    folderOverrides: const {},
    minDuration: Duration.zero,
  );

  final List<Song> songs;
  final List<FolderInfo> folders;
  final List<Album> albums;
  final List<Artist> artists;
  final Map<int, Song> _byId;

  Song? byId(int id) => _byId[id];

  List<Song> resolve(Iterable<int> ids) => [for (final id in ids) ?_byId[id]];

  List<Song> inFolder(String folder) =>
      songs.where((s) => s.folder == folder).toList();

  List<Song> get recentlyAdded =>
      [...songs]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

  static List<Album> _groupAlbums(List<Song> songs) {
    final groups = <int, List<Song>>{};
    for (final song in songs) {
      groups.putIfAbsent(song.albumId, () => []).add(song);
    }
    return [
      for (final group in groups.values)
        Album(
          id: group.first.albumId,
          title: group.first.album,
          artist: _mostCommon(group.map((s) => s.artist)),
          songs: group..sort((a, b) => a.track.compareTo(b.track)),
        ),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  static List<Artist> _groupArtists(List<Song> songs) {
    final groups = <String, List<Song>>{};
    for (final song in songs) {
      groups.putIfAbsent(song.artist, () => []).add(song);
    }
    return [
      for (final entry in groups.entries)
        Artist(name: entry.key, songs: entry.value),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static String _mostCommon(Iterable<String> values) {
    final counts = <String, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}

int compareByTitle(Song a, Song b) =>
    a.title.toLowerCase().compareTo(b.title.toLowerCase());

enum SongSort {
  title('título'),
  artist('artista'),
  album('álbum'),
  recent('recientes'),
  duration('duración');

  const SongSort(this.label);

  final String label;

  List<Song> apply(List<Song> songs) {
    final sorted = [...songs];
    switch (this) {
      case SongSort.title:
        sorted.sort(compareByTitle);
      case SongSort.artist:
        sorted.sort((a, b) {
          final byArtist = a.artist.toLowerCase().compareTo(
            b.artist.toLowerCase(),
          );
          return byArtist != 0 ? byArtist : compareByTitle(a, b);
        });
      case SongSort.album:
        sorted.sort((a, b) {
          final byAlbum = a.album.toLowerCase().compareTo(
            b.album.toLowerCase(),
          );
          return byAlbum != 0 ? byAlbum : a.track.compareTo(b.track);
        });
      case SongSort.recent:
        sorted.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case SongSort.duration:
        sorted.sort((a, b) => b.duration.compareTo(a.duration));
    }
    return sorted;
  }
}

/// Accent- and case-insensitive search over title, artist and album.
List<Song> searchSongs(List<Song> songs, String query) {
  final q = normalizeForSearch(query.trim());
  if (q.isEmpty) return const [];
  return songs
      .where(
        (s) =>
            normalizeForSearch(s.title).contains(q) ||
            normalizeForSearch(s.artist).contains(q) ||
            normalizeForSearch(s.album).contains(q),
      )
      .toList();
}

String normalizeForSearch(String text) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    buffer.write(i == -1 ? char : to[i]);
  }
  return buffer.toString();
}
