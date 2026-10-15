/// Listening time per day and plays per song, all local.
class ListeningStats {
  const ListeningStats({this.secondsByDay = const {}, this.plays = const {}});

  static const keepDays = 120;

  /// "2026-10-15" → seconds actually played that day.
  final Map<String, int> secondsByDay;

  /// Song id → times it started playing.
  final Map<int, int> plays;

  ListeningStats addSeconds(DateTime when, int seconds) {
    if (seconds <= 0) return this;
    final key = dayKey(when);
    return ListeningStats(
      secondsByDay: {...secondsByDay, key: (secondsByDay[key] ?? 0) + seconds},
      plays: plays,
    );
  }

  ListeningStats addPlay(int songId) => ListeningStats(
    secondsByDay: secondsByDay,
    plays: {...plays, songId: (plays[songId] ?? 0) + 1},
  );

  /// Drops days older than [keepDays] so storage doesn't grow forever.
  ListeningStats prune(DateTime now) {
    final oldest = dayKey(now.subtract(const Duration(days: keepDays)));
    return ListeningStats(
      secondsByDay: {
        for (final e in secondsByDay.entries)
          if (e.key.compareTo(oldest) >= 0) e.key: e.value,
      },
      plays: plays,
    );
  }

  int secondsOn(DateTime day) => secondsByDay[dayKey(day)] ?? 0;

  /// Most played song ids, most played first.
  List<int> topSongs(int count) {
    final entries = plays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries.take(count)) e.key];
  }

  Map<String, Object> toJson() => {
    'days': secondsByDay,
    'plays': {for (final e in plays.entries) '${e.key}': e.value},
  };

  factory ListeningStats.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const ListeningStats();
    final days = json['days'];
    final plays = json['plays'];
    return ListeningStats(
      secondsByDay: {
        if (days is Map<String, Object?>)
          for (final e in days.entries)
            if (e.value is int) e.key: e.value! as int,
      },
      plays: {
        if (plays is Map<String, Object?>)
          for (final e in plays.entries)
            if (int.tryParse(e.key) case final id? when e.value is int)
              id: e.value! as int,
      },
    );
  }
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Monday of the week that contains [day], at midnight.
DateTime weekStart(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

const weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const weekdayNames = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

class WeekSummary {
  const WeekSummary({
    required this.minutes,
    required this.todayIndex,
    required this.favoriteWeekday,
  });

  /// Monday..Sunday of the current week.
  final List<int> minutes;

  /// 0 = Monday.
  final int todayIndex;

  /// Weekday with the highest average over the last 4 weeks, or -1.
  final int favoriteWeekday;

  int get totalMinutes => minutes.fold(0, (a, b) => a + b);

  /// Day of this week with the most minutes, or -1 if nothing yet.
  int get bestIndex {
    var best = -1;
    for (var i = 0; i < minutes.length; i++) {
      if (minutes[i] > 0 && (best == -1 || minutes[i] > minutes[best])) {
        best = i;
      }
    }
    return best;
  }
}

/// This week day by day, plus which weekday you listen to the most.
WeekSummary summarizeWeek(ListeningStats stats, DateTime now) {
  final monday = weekStart(now);
  // Se suma con DateTime(año, mes, día + n) y no con Duration para que los
  // cambios de horario no muevan el día.
  DateTime dayOf(DateTime base, int offset) =>
      DateTime(base.year, base.month, base.day + offset);

  final minutes = [
    for (var i = 0; i < 7; i++) stats.secondsOn(dayOf(monday, i)) ~/ 60,
  ];

  final totals = List.filled(7, 0);
  for (var i = 0; i < 28; i++) {
    final day = dayOf(DateTime(now.year, now.month, now.day), -i);
    totals[day.weekday - 1] += stats.secondsOn(day);
  }
  var favorite = -1;
  for (var i = 0; i < 7; i++) {
    if (totals[i] > 0 && (favorite == -1 || totals[i] > totals[favorite])) {
      favorite = i;
    }
  }

  return WeekSummary(
    minutes: minutes,
    todayIndex: now.weekday - 1,
    favoriteWeekday: favorite,
  );
}
