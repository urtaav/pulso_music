enum VisualizerStyle {
  bars('Barras'),
  pulse('Bocina'),
  wave('Onda');

  const VisualizerStyle(this.label);

  final String label;
}

class Settings {
  const Settings({
    this.minDurationSeconds = 30,
    this.accent = 0xFFF2F25A,
    this.visualizerEnabled = true,
    this.visualizerStyle = VisualizerStyle.bars,
    this.visualizerIntensity = 0.7,
    this.askedVisualizerPermission = false,
    this.widgetBackground = 0xFF1C1C1C,
    this.widgetAccent = 0xFFF2F25A,
    this.widgetOpacity = 1,
  });

  final int minDurationSeconds;
  final int accent;
  final bool visualizerEnabled;
  final VisualizerStyle visualizerStyle;

  /// 0.2..1
  final double visualizerIntensity;
  final bool askedVisualizerPermission;
  final int widgetBackground;
  final int widgetAccent;

  /// 0.3..1
  final double widgetOpacity;

  Duration get minDuration => Duration(seconds: minDurationSeconds);

  Settings copyWith({
    int? minDurationSeconds,
    int? accent,
    bool? visualizerEnabled,
    VisualizerStyle? visualizerStyle,
    double? visualizerIntensity,
    bool? askedVisualizerPermission,
    int? widgetBackground,
    int? widgetAccent,
    double? widgetOpacity,
  }) {
    return Settings(
      minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
      accent: accent ?? this.accent,
      visualizerEnabled: visualizerEnabled ?? this.visualizerEnabled,
      visualizerStyle: visualizerStyle ?? this.visualizerStyle,
      visualizerIntensity: visualizerIntensity ?? this.visualizerIntensity,
      askedVisualizerPermission:
          askedVisualizerPermission ?? this.askedVisualizerPermission,
      widgetBackground: widgetBackground ?? this.widgetBackground,
      widgetAccent: widgetAccent ?? this.widgetAccent,
      widgetOpacity: widgetOpacity ?? this.widgetOpacity,
    );
  }

  Map<String, Object> toJson() => {
    'minDurationSeconds': minDurationSeconds,
    'accent': accent,
    'visualizerEnabled': visualizerEnabled,
    'visualizerStyle': visualizerStyle.name,
    'visualizerIntensity': visualizerIntensity,
    'askedVisualizerPermission': askedVisualizerPermission,
    'widgetBackground': widgetBackground,
    'widgetAccent': widgetAccent,
    'widgetOpacity': widgetOpacity,
  };

  factory Settings.fromJson(Map<String, Object?> json) {
    const d = Settings();
    T read<T>(String key, T fallback) {
      final value = json[key];
      return value is T ? value : fallback;
    }

    double readDouble(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return Settings(
      minDurationSeconds: read('minDurationSeconds', d.minDurationSeconds),
      accent: read('accent', d.accent),
      visualizerEnabled: read('visualizerEnabled', d.visualizerEnabled),
      visualizerStyle:
          VisualizerStyle.values.asNameMap()[json['visualizerStyle']] ??
          d.visualizerStyle,
      visualizerIntensity: readDouble(
        'visualizerIntensity',
        d.visualizerIntensity,
      ).clamp(0.2, 1),
      askedVisualizerPermission: read(
        'askedVisualizerPermission',
        d.askedVisualizerPermission,
      ),
      widgetBackground: read('widgetBackground', d.widgetBackground),
      widgetAccent: read('widgetAccent', d.widgetAccent),
      widgetOpacity: readDouble('widgetOpacity', d.widgetOpacity).clamp(0.3, 1),
    );
  }
}

class Playlist {
  const Playlist({required this.id, required this.name, required this.songIds});

  final String id;
  final String name;
  final List<int> songIds;

  Playlist copyWith({String? name, List<int>? songIds}) => Playlist(
    id: id,
    name: name ?? this.name,
    songIds: songIds ?? this.songIds,
  );

  Map<String, Object> toJson() => {'id': id, 'name': name, 'songIds': songIds};

  static Playlist? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final ids = json['songIds'];
    if (id is! String || name is! String) return null;
    return Playlist(
      id: id,
      name: name,
      songIds: ids is List ? ids.whereType<int>().toList() : [],
    );
  }
}

/// What was playing when the app closed.
class PlaybackSession {
  const PlaybackSession({
    required this.songIds,
    required this.index,
    required this.position,
    this.shuffle = false,
    this.repeat = 0,
  });

  final List<int> songIds;
  final int index;
  final Duration position;
  final bool shuffle;

  /// 0 off, 1 all, 2 one.
  final int repeat;

  Map<String, Object> toJson() => {
    'songIds': songIds,
    'index': index,
    'positionMs': position.inMilliseconds,
    'shuffle': shuffle,
    'repeat': repeat,
  };

  static PlaybackSession? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final ids = json['songIds'];
    if (ids is! List) return null;
    final index = json['index'];
    final position = json['positionMs'];
    final repeat = json['repeat'];
    return PlaybackSession(
      songIds: ids.whereType<int>().toList(),
      index: index is int ? index : 0,
      position: Duration(milliseconds: position is int ? position : 0),
      shuffle: json['shuffle'] == true,
      repeat: repeat is int ? repeat.clamp(0, 2) : 0,
    );
  }
}
