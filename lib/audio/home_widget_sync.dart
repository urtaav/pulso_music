import 'package:audio_service/audio_service.dart';
import 'package:home_widget/home_widget.dart';

import '../data/settings.dart';

/// Keeps the home screen widget (PlayerWidgetProvider.kt) in sync.
///
/// Values go as strings: ARGB colors don't fit in a Java Int and home_widget
/// would store them as Int or Long depending on the value.
class HomeWidgetSync {
  static const _provider = 'com.example.pulso_music.PlayerWidgetProvider';

  String? _lastPushed;

  Future<void> push({
    required MediaItem? item,
    required bool playing,
    required Settings settings,
  }) async {
    final data = {
      'title': item?.title ?? 'pulso',
      'artist': item?.artist ?? 'toca para empezar',
      'playing': '$playing',
      'songId': '${item?.extras?['songId'] ?? ''}',
      'background': '${settings.widgetBackground}',
      'accent': '${settings.widgetAccent}',
      'alpha': '${(settings.widgetOpacity * 255).round()}',
    };
    final key = data.toString();
    if (key == _lastPushed) return;
    _lastPushed = key;

    for (final entry in data.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
  }
}
