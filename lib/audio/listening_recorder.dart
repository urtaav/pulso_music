import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../data/listening_stats.dart';
import '../data/song.dart';

/// Registra cuánto escuchas cada día y cuántas veces suena cada canción.
///
/// Solo cuenta el tiempo con la música realmente sonando: mide el reloj entre
/// muestras mientras `playing` es verdadero y descarta saltos largos (por
/// ejemplo, si el teléfono durmió el proceso), así una pausa larga no infla
/// las estadísticas.
class ListeningRecorder {
  ListeningRecorder({
    required ListeningStats initial,
    required this.save,
    DateTime Function()? clock,
  }) : _stats = initial,
       _clock = clock ?? DateTime.now;

  static const _sampleEvery = Duration(seconds: 15);
  static const _maxGap = Duration(seconds: 45);

  final Future<void> Function(ListeningStats stats) save;
  final DateTime Function() _clock;
  final _changes = StreamController<ListeningStats>.broadcast();

  ListeningStats _stats;
  DateTime? _playingSince;
  Timer? _timer;
  StreamSubscription<PlaybackState>? _stateSub;
  StreamSubscription<Song>? _startedSub;

  ListeningStats get stats => _stats;
  Stream<ListeningStats> get changes => _changes.stream;

  void attach({
    required Stream<PlaybackState> playbackState,
    required Stream<Song> songStarted,
  }) {
    _stateSub = playbackState.listen((state) => _onPlaying(state.playing));
    _startedSub = songStarted.listen((song) {
      _update(_stats.addPlay(song.id));
    });
    _timer = Timer.periodic(_sampleEvery, (_) => _flush());
  }

  void _onPlaying(bool playing) {
    if (playing) {
      _playingSince ??= _clock();
    } else {
      _flush();
      _playingSince = null;
    }
  }

  /// Adds the time since the last sample, if music was playing.
  void _flush() {
    final since = _playingSince;
    if (since == null) return;
    final now = _clock();
    final elapsed = now.difference(since);
    _playingSince = now;
    if (elapsed <= Duration.zero || elapsed > _maxGap) return;
    _update(_stats.addSeconds(now, elapsed.inSeconds).prune(now));
  }

  void _update(ListeningStats next) {
    _stats = next;
    _changes.add(next);
    save(next);
  }

  Future<void> dispose() async {
    _flush();
    _timer?.cancel();
    await _stateSub?.cancel();
    await _startedSub?.cancel();
    await _changes.close();
  }
}
