import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulso_music/data/listening_stats.dart';
import 'package:pulso_music/data/shuffle.dart';
import 'package:pulso_music/data/song.dart';

Song song(int id, String artist) => Song(
  id: id,
  title: 't$id',
  artist: artist,
  album: 'a',
  albumId: 1,
  duration: const Duration(minutes: 3),
  path: '/m/$id.mp3',
  folder: '/m',
  dateAdded: DateTime(2026),
);

bool hasArtistRepeat(List<Song> songs) {
  for (var i = 1; i < songs.length; i++) {
    if (songs[i].artist == songs[i - 1].artist) return true;
  }
  return false;
}

void main() {
  group('shuffleWithoutRepeats', () {
    final library = [for (var i = 0; i < 20; i++) song(i, 'artista ${i % 5}')];

    test('unheard songs always come first', () {
      final played = {0, 1, 2, 3, 4, 5, 6, 7};
      for (var seed = 0; seed < 20; seed++) {
        final order = shuffleWithoutRepeats(library, played, Random(seed));
        final firstTwelve = order.songs.take(12).map((s) => s.id);
        expect(firstTwelve.any(played.contains), isFalse, reason: 'seed $seed');
        expect(order.startedNewCycle, isFalse);
      }
    });

    test('keeps every song exactly once', () {
      final order = shuffleWithoutRepeats(library, {3, 9}, Random(1));
      expect(
        order.songs.map((s) => s.id).toList()..sort(),
        List.generate(20, (i) => i),
      );
    });

    test('starts a new cycle when everything already played', () {
      final all = {for (final s in library) s.id};
      final order = shuffleWithoutRepeats(library, all, Random(2));
      expect(order.startedNewCycle, isTrue);
      expect(order.songs, hasLength(20));
    });

    test('a whole cycle never repeats a song', () {
      final history = ShuffleHistory(played: {}, save: (_) async {});
      final heard = <int>[];
      final random = Random(3);
      // Simula escuchar una canción por sesión de aleatorio.
      for (var i = 0; i < library.length; i++) {
        final order = shuffleWithoutRepeats(library, history.played, random);
        final first = order.songs.first;
        heard.add(first.id);
        history.markPlayed(first.id);
      }
      expect(heard.toSet(), hasLength(library.length));
    });

    test('the same artist does not play twice in a row', () {
      for (var seed = 0; seed < 30; seed++) {
        final order = shuffleWithoutRepeats(library, {}, Random(seed));
        expect(hasArtistRepeat(order.songs), isFalse, reason: 'seed $seed');
      }
    });
  });

  group('spreadArtists', () {
    test('separates neighbours when possible', () {
      final list = [song(1, 'a'), song(2, 'a'), song(3, 'b'), song(4, 'b')];
      expect(hasArtistRepeat(spreadArtists(list)), isFalse);
    });

    test('leaves a single-artist list alone', () {
      final list = [song(1, 'a'), song(2, 'a')];
      expect(spreadArtists(list).map((s) => s.id), [1, 2]);
    });
  });

  test(
    'ShuffleHistory saves only on real changes and forgets per collection',
    () {
      var saves = 0;
      final history = ShuffleHistory(played: {}, save: (_) async => saves++);
      history
        ..markPlayed(1)
        ..markPlayed(1)
        ..markPlayed(2)
        ..forget([1, 99]);
      expect(history.played, {2});
      expect(saves, 3);
    },
  );

  group('ListeningStats', () {
    final thursday = DateTime(2026, 10, 15, 21);

    test('adds seconds per day and plays per song', () {
      final stats = const ListeningStats()
          .addSeconds(thursday, 120)
          .addSeconds(thursday, 60)
          .addPlay(7)
          .addPlay(7)
          .addPlay(3);
      expect(stats.secondsOn(thursday), 180);
      expect(stats.topSongs(2), [7, 3]);
    });

    test('summarizes the current week from Monday', () {
      final stats = const ListeningStats()
          .addSeconds(DateTime(2026, 10, 12, 9), 600) // lunes
          .addSeconds(DateTime(2026, 10, 15, 9), 1800) // jueves
          .addSeconds(DateTime(2026, 10, 11, 9), 9999); // domingo anterior
      final week = summarizeWeek(stats, thursday);
      expect(week.minutes, [10, 0, 0, 30, 0, 0, 0]);
      expect(week.totalMinutes, 40);
      expect(week.bestIndex, 3);
      expect(week.todayIndex, 3);
    });

    test('favorite weekday looks at the last four weeks', () {
      var stats = const ListeningStats();
      for (final day in [3, 10]) {
        stats = stats.addSeconds(DateTime(2026, 10, day), 3600); // sábados
      }
      stats = stats.addSeconds(DateTime(2026, 10, 14), 600); // miércoles
      expect(summarizeWeek(stats, thursday).favoriteWeekday, 5);
    });

    test('empty stats have no best day', () {
      final week = summarizeWeek(const ListeningStats(), thursday);
      expect(week.bestIndex, -1);
      expect(week.favoriteWeekday, -1);
    });

    test('prunes old days and survives JSON', () {
      final stats = const ListeningStats()
          .addSeconds(DateTime(2026, 1, 1), 100)
          .addSeconds(thursday, 50)
          .addPlay(4)
          .prune(thursday);
      final back = ListeningStats.fromJson(stats.toJson());
      expect(back.secondsByDay.keys, ['2026-10-15']);
      expect(back.plays, {4: 1});
      expect(ListeningStats.fromJson('basura').plays, isEmpty);
    });

    test('week start handles Sunday', () {
      expect(weekStart(DateTime(2026, 10, 18, 23)), DateTime(2026, 10, 12));
    });
  });
}
