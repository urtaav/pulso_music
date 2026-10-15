/// "3:07", or "1:02:45" for long audio.
String formatDuration(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// "2 h 05 min", "45 min" for totals.
String formatTotal(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  return '$hours h ${minutes.toString().padLeft(2, '0')} min';
}

String songCount(int count) => count == 1 ? '1 canción' : '$count canciones';

String greetingFor(DateTime now) => switch (now.hour) {
  < 6 => 'Buenas noches',
  < 12 => 'Buenos días',
  < 19 => 'Buenas tardes',
  _ => 'Buenas noches',
};
