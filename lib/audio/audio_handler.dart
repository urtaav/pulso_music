import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/library.dart';
import '../data/settings.dart';
import '../data/song.dart';

class SleepTimerState {
  const SleepTimerState({this.endsAt, this.endOfTrack = false});

  static const off = SleepTimerState();

  final DateTime? endsAt;
  final bool endOfTrack;

  bool get isActive => endsAt != null || endOfTrack;
}

/// Servicio de reproducción.
///
/// audio_service lo expone a Android como MediaSession: de ahí salen la
/// notificación multimedia, los controles en pantalla de bloqueo y los botones
/// de audífonos. just_audio (ExoPlayer) reproduce y, con handleInterruptions,
/// pausa en llamadas y baja el volumen cuando otra app suena brevemente.
///
/// La cola es la lista [_songs] en el mismo orden que ExoPlayer. El aleatorio
/// reordena esa lista en lugar de usar el shuffle interno de just_audio, así la
/// cola que ve el usuario es exactamente lo que va a sonar y se puede editar.
class PulsoAudioHandler extends BaseAudioHandler with SeekHandler {
  PulsoAudioHandler({required this.saveSession}) {
    _init();
  }

  /// Persists the session (last song, position, queue).
  final Future<void> Function(PlaybackSession session) saveSession;

  /// Called when play is pressed with nothing queued (notification, widget).
  Future<void> Function()? onEmptyQueuePlay;

  final _player = AudioPlayer();
  final _random = Random();
  final _songStarted = StreamController<Song>.broadcast();
  final _sleep = StreamController<SleepTimerState>.broadcast();

  List<Song> _songs = [];
  List<int>? _orderBeforeShuffle;
  bool _shuffle = false;
  int? _lastStartedIndex;
  bool _restoring = false;
  Timer? _sleepTimer;
  SleepTimerState _sleepState = SleepTimerState.off;
  Timer? _autosave;

  Stream<Song> get songStarted => _songStarted.stream;
  Stream<int?> get audioSessionId => _player.androidAudioSessionIdStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _player.position;
  List<Song> get songs => List.unmodifiable(_songs);
  bool get isEmpty => _songs.isEmpty;

  Song? get currentSong {
    final index = _player.currentIndex;
    return index != null && index < _songs.length ? _songs[index] : null;
  }

  SleepTimerState get sleepState => _sleepState;
  Stream<SleepTimerState> get sleepStream => _sleep.stream;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Al desconectar audífonos Android avisa "becoming noisy": pausamos para
    // que la música no salga de golpe por la bocina.
    session.becomingNoisyEventStream.listen((_) => pause());

    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object error, StackTrace stack) => _skipBroken(),
    );
    _player.playingStream.listen((playing) {
      _broadcastState();
      if (!playing) _persist();
    });
    _player.currentIndexStream.listen(_onIndexChanged);
    _player.positionDiscontinuityStream.listen((event) {
      if (event.reason == PositionDiscontinuityReason.autoAdvance &&
          _sleepState.endOfTrack) {
        pause();
        cancelSleepTimer();
      }
    });
    _player.processingStateStream.listen((state) {
      if (state != ProcessingState.completed) return;
      // Fin de la cola: queda lista para volver a empezar, en pausa.
      if (_sleepState.endOfTrack) cancelSleepTimer();
      _player.pause();
      if (_songs.isNotEmpty) _player.seek(Duration.zero, index: 0);
    });
    _autosave = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_player.playing) _persist();
    });
  }

  // ---- Cargar música ----

  Future<void> playSongs(
    List<Song> songs, {
    int startIndex = 0,
    bool shuffle = false,
  }) async {
    if (songs.isEmpty) return;
    var list = [...songs];
    var index = startIndex.clamp(0, list.length - 1);
    if (shuffle) {
      list.shuffle(_random);
      index = 0;
    }
    _shuffle = shuffle;
    _orderBeforeShuffle = shuffle ? [for (final s in songs) s.id] : null;
    await _load(list, index, Duration.zero);
    unawaited(_player.play());
  }

  /// Loads the last session paused, without counting it as "played".
  Future<void> restore(PlaybackSession session, Library library) async {
    final songs = library.resolve(session.songIds);
    if (songs.isEmpty) return;
    final wantedId = session.index < session.songIds.length
        ? session.songIds[session.index]
        : null;
    final index = max(0, songs.indexWhere((s) => s.id == wantedId));
    _shuffle = session.shuffle;
    _orderBeforeShuffle = null;
    _restoring = true;
    try {
      await _player.setLoopMode(LoopMode.values[session.repeat]);
      await _load(songs, index, session.position);
    } finally {
      _restoring = false;
    }
  }

  Future<void> _load(List<Song> list, int index, Duration position) async {
    _songs = list;
    _lastStartedIndex = _restoring ? index : null;
    _publishQueue();
    try {
      await _player.setAudioSources(
        [for (final s in list) AudioSource.uri(Uri.parse(s.uri), tag: s.id)],
        initialIndex: index,
        initialPosition: position,
      );
    } on PlayerException {
      await _skipBroken();
    }
    _broadcastState();
  }

  // ---- Controles básicos ----

  @override
  Future<void> play() async {
    if (_songs.isEmpty) {
      await onEmptyQueuePlay?.call();
      return;
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await _persist();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> togglePlay() => _player.playing ? pause() : play();

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_songs.isNotEmpty && _player.loopMode != LoopMode.off) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Como en cualquier reproductor: si ya avanzó, primero reinicia la canción.
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _songs.length) return;
    await _player.seek(Duration.zero, index: index);
    unawaited(_player.play());
  }

  // ---- Cola ----

  Future<void> playNext(Song song) async {
    if (_songs.isEmpty) return playSongs([song]);
    final index = (_player.currentIndex ?? -1) + 1;
    _songs.insert(index, song);
    _orderBeforeShuffle?.add(song.id);
    await _player.insertAudioSource(index, _source(song));
    _publishQueue();
  }

  Future<void> addToQueue(Song song) async {
    if (_songs.isEmpty) return playSongs([song]);
    _songs.add(song);
    _orderBeforeShuffle?.add(song.id);
    await _player.addAudioSource(_source(song));
    _publishQueue();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _songs.length) return;
    if (_songs.length == 1) {
      await _player.stop();
      await _player.clearAudioSources();
      _songs = [];
      _publishQueue();
      mediaItem.add(null);
      return;
    }
    _songs.removeAt(index);
    await _player.removeAudioSourceAt(index);
    _publishQueue();
  }

  /// [to] is the final position of the moved song.
  Future<void> moveQueueItem(int from, int to) async {
    if (from == to || from < 0 || from >= _songs.length) return;
    final target = to.clamp(0, _songs.length - 1);
    _songs.insert(target, _songs.removeAt(from));
    await _player.moveAudioSource(from, target);
    _publishQueue();
  }

  // ---- Aleatorio y repetir ----

  bool get shuffleEnabled => _shuffle;

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enable = shuffleMode != AudioServiceShuffleMode.none;
    if (enable == _shuffle || _songs.isEmpty) {
      _shuffle = enable;
      _broadcastState();
      return;
    }
    final current = currentSong;
    List<Song> target;
    if (enable) {
      _orderBeforeShuffle = [for (final s in _songs) s.id];
      final rest = [..._songs]..removeWhere((s) => identical(s, current));
      rest.shuffle(_random);
      target = [?current, ...rest];
    } else {
      target = _originalOrder();
      _orderBeforeShuffle = null;
    }
    _shuffle = enable;
    await _reorderTo(target);
    _broadcastState();
  }

  Future<void> toggleShuffle() => setShuffleMode(
    _shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
  );

  List<Song> _originalOrder() {
    final order = _orderBeforeShuffle;
    if (order == null) return [..._songs];
    final pool = [..._songs];
    final result = <Song>[];
    for (final id in order) {
      final i = pool.indexWhere((s) => s.id == id);
      if (i != -1) result.add(pool.removeAt(i));
    }
    return result..addAll(pool);
  }

  /// Reorders with moves so the current song keeps playing without a gap.
  Future<void> _reorderTo(List<Song> target) async {
    for (var i = 0; i < target.length; i++) {
      final j = _songs.indexWhere((s) => identical(s, target[i]), i);
      if (j == -1 || j == i) continue;
      _songs.insert(i, _songs.removeAt(j));
      await _player.moveAudioSource(j, i);
    }
    _publishQueue();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      _ => LoopMode.all,
    });
    _broadcastState();
  }

  /// off → all → one → off
  Future<void> cycleRepeat() => setRepeatMode(switch (_player.loopMode) {
    LoopMode.off => AudioServiceRepeatMode.all,
    LoopMode.all => AudioServiceRepeatMode.one,
    LoopMode.one => AudioServiceRepeatMode.none,
  });

  // ---- Temporizador de apagado ----

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () {
      pause();
      cancelSleepTimer();
    });
    _setSleep(SleepTimerState(endsAt: DateTime.now().add(duration)));
  }

  void sleepAtEndOfTrack() {
    _sleepTimer?.cancel();
    _setSleep(const SleepTimerState(endOfTrack: true));
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _setSleep(SleepTimerState.off);
  }

  void _setSleep(SleepTimerState state) {
    _sleepState = state;
    _sleep.add(state);
  }

  // ---- Estado hacia Android y la UI ----

  void _onIndexChanged(int? index) {
    if (index == null || index >= _songs.length) return;
    final song = _songs[index];
    mediaItem.add(_toMediaItem(song));
    if (index != _lastStartedIndex && !_restoring) {
      _songStarted.add(song);
    }
    _lastStartedIndex = index;
    _persist();
  }

  void _publishQueue() {
    queue.add([for (final s in _songs) _toMediaItem(s)]);
    final index = _player.currentIndex;
    if (index != null && index < _songs.length) {
      mediaItem.add(_toMediaItem(_songs[index]));
    }
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
        shuffleMode: _shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (_player.loopMode) {
          LoopMode.off => AudioServiceRepeatMode.none,
          LoopMode.one => AudioServiceRepeatMode.one,
          LoopMode.all => AudioServiceRepeatMode.all,
        },
      ),
    );
  }

  /// A deleted or unreadable file shouldn't stop the whole queue.
  Future<void> _skipBroken() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      unawaited(_player.play());
    } else {
      await _player.pause();
    }
  }

  Future<void> _persist() async {
    if (_songs.isEmpty) return;
    await saveSession(
      PlaybackSession(
        songIds: [for (final s in _songs) s.id],
        index: _player.currentIndex ?? 0,
        position: _player.position,
        shuffle: _shuffle,
        repeat: _player.loopMode.index,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() => _persist();

  AudioSource _source(Song song) =>
      AudioSource.uri(Uri.parse(song.uri), tag: song.id);

  static MediaItem _toMediaItem(Song song) => MediaItem(
    id: '${song.id}',
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.duration,
    artUri: Uri.parse(
      'content://media/external/audio/albumart/${song.albumId}',
    ),
    extras: {'songId': song.id},
  );

  Future<void> dispose() async {
    _autosave?.cancel();
    _sleepTimer?.cancel();
    await _player.dispose();
  }
}
