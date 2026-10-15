import '../../audio/audio_handler.dart';

/// Actions sent by the home screen widget buttons (WidgetActionReceiver.kt).
Future<void> runWidgetAction(PulsoAudioHandler handler, String action) {
  return switch (action) {
    'playPause' => handler.togglePlay(),
    'next' => handler.skipToNext(),
    'previous' => handler.skipToPrevious(),
    _ => Future.value(),
  };
}
