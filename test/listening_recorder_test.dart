import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso_music/audio/listening_recorder.dart';
import 'package:pulso_music/data/listening_stats.dart';
import 'package:pulso_music/data/song.dart';

void main() {
  late DateTime now;
  late StreamController<PlaybackState> states;
  late StreamController<Song> started;
  late ListeningRecorder recorder;

  PlaybackState state({required bool playing}) =>
      PlaybackState(playing: playing);

  Future<void> emit(bool playing) async {
    states.add(state(playing: playing));
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    now = DateTime(2026, 10, 15, 20);
    states = StreamController<PlaybackState>();
    started = StreamController<Song>();
    recorder = ListeningRecorder(
      initial: const ListeningStats(),
      save: (_) async {},
      clock: () => now,
    )..attach(playbackState: states.stream, songStarted: started.stream);
  });

  tearDown(() async {
    await recorder.dispose();
    await states.close();
    await started.close();
  });

  test('counts only the time music is playing', () async {
    await emit(true);
    now = now.add(const Duration(seconds: 30));
    await emit(false); // pausa: se suman 30 s
    now = now.add(const Duration(minutes: 10)); // en pausa, no cuenta
    await emit(true);
    now = now.add(const Duration(seconds: 20));
    await emit(false);
    expect(recorder.stats.secondsOn(now), 50);
  });

  test('ignores long gaps, like a frozen process', () async {
    await emit(true);
    now = now.add(const Duration(minutes: 5));
    await emit(false);
    expect(recorder.stats.secondsOn(now), 0);
  });

  test('counts a play each time a song starts', () async {
    final song = Song(
      id: 9,
      title: 't',
      artist: 'a',
      album: 'b',
      albumId: 1,
      duration: const Duration(minutes: 3),
      path: '/m/9.mp3',
      folder: '/m',
      dateAdded: DateTime(2026),
    );
    started
      ..add(song)
      ..add(song);
    await Future<void>.delayed(Duration.zero);
    expect(recorder.stats.plays[9], 2);
  });
}
