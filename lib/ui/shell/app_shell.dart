import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/home_widget_sync.dart';
import '../../data/library.dart';
import '../../state/providers.dart';
import '../player/mini_player.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../visualizer/edge_visualizer.dart';
import 'widget_actions.dart';

/// Tabs with their own navigation stack, plus the mini player and the
/// navigation bar that stay visible on every screen.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = [
    HomeScreen(),
    LibraryScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];
  static const _rescanAfter = Duration(minutes: 5);

  final _navigators = List.generate(
    _tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );
  final _widgetSync = HomeWidgetSync();
  late final AppLifecycleListener _lifecycle;
  int _tab = 0;
  bool _bootstrapped = false;
  DateTime _lastScan = DateTime.now();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);

    ref.listenManual(libraryProvider, (_, next) {
      final library = next.value;
      if (library != null && !_bootstrapped) {
        _bootstrapped = true;
        _bootstrap(library);
      }
    }, fireImmediately: true);

    ref.listenManual(isPlayingProvider, (_, playing) {
      if (playing) _maybeAskVisualizerPermission();
      _pushWidget();
    });
    ref.listenManual(mediaItemProvider, (_, _) => _pushWidget());
    ref.listenManual(settingsProvider, (_, _) => _pushWidget());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _bootstrap(Library library) async {
    final handler = ref.read(audioHandlerProvider);
    // Play desde la notificación o el widget sin nada en cola: aleatorio todo.
    handler.onEmptyQueuePlay = () =>
        handler.playSongs(ref.read(libraryValueProvider).songs, shuffle: true);
    if (handler.isEmpty) {
      final session = ref.read(userStoreProvider).loadSession();
      if (session != null) await handler.restore(session, library);
    }
    // Botón del widget tocado con la app cerrada.
    final action = await ref.read(mediaStoreProvider).consumeLaunchAction();
    if (action != null) await runWidgetAction(handler, action);
    await _pushWidget();
  }

  void _onResume() {
    // "Actualización al abrir la app": reescanea si pasó un rato.
    if (DateTime.now().difference(_lastScan) > _rescanAfter) {
      _lastScan = DateTime.now();
      ref.read(scannedSongsProvider.notifier).refresh();
    }
    ref.invalidate(micPermissionProvider);
  }

  Future<void> _pushWidget() => _widgetSync.push(
    item: ref.read(mediaItemProvider).value,
    playing: ref.read(isPlayingProvider),
    settings: ref.read(settingsProvider),
  );

  void _maybeAskVisualizerPermission() {
    final settings = ref.read(settingsProvider);
    if (!settings.visualizerEnabled || settings.askedVisualizerPermission) {
      return;
    }
    if (ref.read(micPermissionProvider).value ?? false) return;
    askVisualizerPermission(context, ref);
  }

  void _onBack() {
    final navigator = _navigators[_tab].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else if (_tab != 0) {
      setState(() => _tab = 0);
    } else {
      // La música sigue sonando: el servicio vive aparte de la pantalla.
      SystemNavigator.pop();
    }
  }

  void _selectTab(int index) {
    if (index == _tab) {
      // Tocar la pestaña activa regresa a su pantalla principal.
      _navigators[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _tab = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene vivo el registro de "escuchadas recientemente".
    ref.watch(recentsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Navigator(
                key: _navigators[i],
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => _tabs[i]),
              ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Biblioteca',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: 'Ajustes',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
