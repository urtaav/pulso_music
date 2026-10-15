class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.path,
    required this.folder,
    required this.dateAdded,
    this.track = 0,
    this.isSystemSound = false,
    this.isRecording = false,
  });

  factory Song.fromMap(Map<Object?, Object?> map) {
    String text(String key, String fallback) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value : fallback;
    }

    int number(String key) {
      final value = map[key];
      return value is num ? value.toInt() : 0;
    }

    final path = text('path', '');
    return Song(
      id: number('id'),
      title: text('title', _fileName(path)),
      artist: text('artist', 'Artista desconocido'),
      album: text('album', 'Sin álbum'),
      albumId: number('albumId'),
      duration: Duration(milliseconds: number('durationMs')),
      path: path,
      folder: text('folder', ''),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(
        number('dateAdded') * 1000,
      ),
      track: number('track'),
      isSystemSound: map['isSystemSound'] == true,
      isRecording: map['isRecording'] == true,
    );
  }

  final int id;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final Duration duration;
  final String path;
  final String folder;
  final DateTime dateAdded;
  final int track;
  final bool isSystemSound;
  final bool isRecording;

  String get uri => 'content://media/external/audio/media/$id';

  String get folderName => folderLabel(folder);

  static String _fileName(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0
        ? name.substring(0, dot)
        : (name.isEmpty ? 'Sin título' : name);
  }
}

/// Last segment of a folder path, e.g. "/storage/emulated/0/Music" → "Music".
String folderLabel(String folder) {
  final parts = folder.split('/').where((p) => p.isNotEmpty);
  return parts.isEmpty ? 'Almacenamiento' : parts.last;
}
