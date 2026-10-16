import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';
import '../common/artwork_palette.dart';
import '../common/artwork.dart';
import '../common/glass.dart';
import '../common/play_pause_button.dart';
import '../common/song_tile.dart';
import '../common/waveform_seek_bar.dart';
import 'queue_sheet.dart';
import 'sleep_timer_sheet.dart';

void openPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      // No opaca: al arrastrarla hacia abajo se ve la app detrás.
      opaque: false,
      // Curva de las hojas de iOS: sale rápido y frena largo y suave.
      transitionDuration: Motion.slow,
      reverseTransitionDuration: Motion.medium,
      pageBuilder: (_, _, _) => const PlayerScreen(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: Motion.sheet,
            reverseCurve: Motion.sheet.flipped,
          ),
        ),
        child: child,
      ),
    ),
  );
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  // Desplazamiento del gesto de cerrar, en píxeles. Sin límites para poder
  // regresarlo con una simulación de resorte.
  late final _drag = AnimationController.unbounded(vsync: this);
  int _swipeDirection = 1;
  bool _closing = false;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _onVerticalUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _drag.value = math.max(0, _drag.value + details.delta.dy);
  }

  void _onVerticalEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.value > 140 || velocity > 700) {
      // Se queda donde va el dedo: la transición de salida continúa desde
      // ahí y no hay salto.
      _closing = true;
      Navigator.pop(context);
      return;
    }
    // Regresa con resorte, conservando la velocidad del dedo.
    _drag.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 320, damping: 32),
        _drag.value,
        0,
        velocity,
      ),
    );
  }

  void _onHorizontalEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final handler = ref.read(audioHandlerProvider);
    if (velocity < -300) {
      setState(() => _swipeDirection = 1);
      handler.skipToNext();
    } else if (velocity > 300) {
      setState(() => _swipeDirection = -1);
      handler.skipToPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalUpdate,
        onVerticalDragEnd: _onVerticalEnd,
        child: AnimatedBuilder(
          animation: _drag,
          builder: (context, child) {
            final offset = math.max(0.0, _drag.value);
            // Mientras se arrastra, la pantalla se vuelve una tarjeta: se
            // encoge un poco y redondea sus esquinas, como en iOS.
            final progress = (offset / 400).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, offset),
              child: Transform.scale(
                scale: 1 - 0.06 * progress,
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40 * progress),
                  child: child,
                ),
              ),
            );
          },
          child: _PlayerBody(
            swipeDirection: _swipeDirection,
            onHorizontalEnd: _onHorizontalEnd,
          ),
        ),
      ),
    );
  }
}

class _PlayerBody extends ConsumerWidget {
  const _PlayerBody({
    required this.swipeDirection,
    required this.onHorizontalEnd,
  });

  final int swipeDirection;
  final GestureDragEndCallback onHorizontalEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    final handler = ref.read(audioHandlerProvider);
    final state = ref.watch(playbackStateProvider).value;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final sleep = ref.watch(sleepTimerProvider).value;
    final accent = Theme.of(context).colorScheme.primary;
    final playing = state?.playing ?? false;
    final shuffle = state?.shuffleMode == AudioServiceShuffleMode.all;
    final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;

    final palette = ref.watch(stablePaletteProvider);
    final screen = MediaQuery.sizeOf(context);
    // La portada ocupa todo el ancho y baja más allá de cuadrada; los
    // controles quedan encima del degradado, como Apple Music en iOS 26.
    final artHeight = math.max(screen.width, screen.height * 0.62);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          color: palette.background,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: artHeight,
          child: AnimatedSwitcher(
            duration: Motion.slow,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            // Al cambiar de canción la portada nueva entra deslizándose un
            // poco desde el lado del gesto mientras se funde.
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween(
                      begin: Offset(0.08 * swipeDirection, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: Motion.sheet),
                    ),
                child: child,
              ),
            ),
            child: Artwork(
              key: ValueKey(song?.id),
              song: song,
              radius: 0,
              highRes: true,
              fill: true,
            ),
          ),
        ),
        // En pausa la portada se apaga un poco en vez de encogerse.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: artHeight,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: playing ? 0 : 0.3,
              duration: Motion.slow,
              curve: Motion.standard,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
        // Degradado: la portada se funde con el color de la canción.
        Positioned(
          left: 0,
          right: 0,
          top: artHeight * 0.4,
          height: artHeight * 0.6 + 1,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.background.withValues(alpha: 0),
                    palette.background.withValues(alpha: 0.75),
                    palette.background,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),
        // Sombra suave arriba para que los botones se lean sobre portadas claras.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 140,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    GlassIconButton(
                      tooltip: 'Minimizar',
                      icon: Icons.keyboard_arrow_down_rounded,
                      iconSize: 28,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    GlassIconButton(
                      tooltip: 'Temporizador',
                      icon: sleep?.isActive == true
                          ? Icons.bedtime_rounded
                          : Icons.bedtime_outlined,
                      onPressed: () => showSleepTimerSheet(context),
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      tooltip: 'Cola',
                      icon: Icons.queue_music_rounded,
                      onPressed: () => showQueueSheet(context),
                    ),
                  ],
                ),
                // Espacio libre sobre la portada; también sirve para el gesto
                // de cambiar de canción.
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: onHorizontalEnd,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        child: Column(
                          key: ValueKey(song?.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song?.title ?? 'Nada sonando',
                              style: TextStyles.display.copyWith(fontSize: 30),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song?.artist ?? '',
                              style: TextStyles.body.copyWith(
                                color: Palette.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (song != null) HeartButton(songId: song.id, size: 28),
                  ],
                ),
                const SizedBox(height: 20),
                WaveformSeekBar(
                  seed: song?.id ?? 0,
                  position: position,
                  duration: song?.duration ?? Duration.zero,
                  color: accent,
                  onSeek: handler.seek,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: shuffle ? 'Desactivar aleatorio' : 'Aleatorio',
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: shuffle ? accent : Palette.grey,
                      ),
                      onPressed: handler.toggleShuffle,
                    ),
                    IconButton(
                      tooltip: 'Anterior',
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: handler.skipToPrevious,
                    ),
                    PlayPauseButton(
                      playing: playing,
                      onPressed: handler.togglePlay,
                      size: 78,
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: handler.skipToNext,
                    ),
                    IconButton(
                      tooltip: switch (repeat) {
                        AudioServiceRepeatMode.one => 'Repitiendo una',
                        AudioServiceRepeatMode.none => 'Repetir',
                        _ => 'Repitiendo todo',
                      },
                      icon: Icon(
                        repeat == AudioServiceRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: repeat == AudioServiceRepeatMode.none
                            ? Palette.grey
                            : accent,
                      ),
                      onPressed: handler.cycleRepeat,
                    ),
                  ],
                ),
                SizedBox(
                  height: 32,
                  child: Center(
                    child: SleepTimerLabel(
                      style: TextStyles.numbers.copyWith(
                        color: accent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
