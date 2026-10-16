import 'package:audio_service/audio_service.dart';
import 'package:home_widget/home_widget.dart';

import '../data/listening_stats.dart';
import '../data/settings.dart';

/// Keeps the home screen widgets (Kotlin providers) in sync.
///
/// Values go as strings: ARGB colors don't fit in a Java Int and home_widget
/// would store them as Int or Long depending on the value.
class HomeWidgetSync {
  static const _providers = [
    'com.example.pulso_music.PlayerWidgetProvider',
    'com.example.pulso_music.CoverWidgetProvider',
    'com.example.pulso_music.StatsWidgetProvider',
  ];

  String? _lastPushed;

  Future<void> push({
    required MediaItem? item,
    required bool playing,
    required Duration position,
    required bool isFavorite,
    required Settings settings,
    required WeekSummary week,
  }) async {
    final data = {
      'title': item?.title ?? 'pulso',
      'artist': item?.artist ?? 'Toca para empezar',
      'playing': '$playing',
      'favorite': '$isFavorite',
      'songId': '${item?.extras?['songId'] ?? ''}',
      'positionMs': '${position.inMilliseconds}',
      'durationMs': '${item?.duration?.inMilliseconds ?? 0}',
      'background': '${settings.widgetBackground}',
      'accent': '${settings.widgetAccent}',
      'alpha': '${(settings.widgetOpacity * 255).round()}',
      'weekMinutes': week.minutes.join(','),
      'weekToday': '${week.todayIndex}',
      'weekBest': '${week.bestIndex}',
    };
    // savedAt fuera de la comparación: cambia siempre y no es un cambio real.
    final key = data.toString();
    if (key == _lastPushed) return;
    _lastPushed = key;

    // El widget calcula el tiempo transcurrido desde aquí para que su reloj
    // avance solo entre actualizaciones.
    data['savedAt'] = '${DateTime.now().millisecondsSinceEpoch}';
    for (final entry in data.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
    for (final provider in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    }
  }
}
