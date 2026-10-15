import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'audio/audio_handler.dart';
import 'audio/listening_recorder.dart';
import 'data/shuffle.dart';
import 'data/user_store.dart';
import 'state/providers.dart';
import 'ui/shell/widget_actions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: la app dibuja detrás de la barra de estado y de navegación.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final store = UserStore(await SharedPreferences.getInstance());
  final handler = await AudioService.init(
    builder: () => PulsoAudioHandler(
      saveSession: store.saveSession,
      shuffleHistory: ShuffleHistory(
        played: store.loadShuffleHistory(),
        save: store.saveShuffleHistory,
      ),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.pulso_music.playback',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final recorder =
      ListeningRecorder(initial: store.loadStats(), save: store.saveStats)
        ..attach(
          playbackState: handler.playbackState,
          songStarted: handler.songStarted,
        );

  // Contenedor propio para que los botones del widget (que llegan por fuera
  // de la UI) usen los mismos providers que la app.
  final container = ProviderContainer(
    overrides: [
      userStoreProvider.overrideWithValue(store),
      audioHandlerProvider.overrideWithValue(handler),
      listeningRecorderProvider.overrideWithValue(recorder),
    ],
  );

  // Botones del widget de inicio mientras la app está viva.
  const MethodChannel('pulso/widget').setMethodCallHandler((call) async {
    if (call.method == 'action' && call.arguments is String) {
      await runWidgetAction(container, call.arguments as String);
    }
  });

  runApp(
    UncontrolledProviderScope(container: container, child: const PulsoApp()),
  );
}
