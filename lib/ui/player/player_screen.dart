import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';
import '../common/adaptive_background.dart';
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
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const PlayerScreen(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
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

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double _dragY = 0;
  int _swipeDirection = 1;

  void _onVerticalEnd(DragEndDetails details) {
    // Deslizar hacia abajo minimiza al mini reproductor.
    if (_dragY > 140 || (details.primaryVelocity ?? 0) > 700) {
      Navigator.pop(context);
    } else {
      setState(() => _dragY = 0);
    }
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
    final song = ref.watch(currentSongProvider);
    final handler = ref.read(audioHandlerProvider);
    final state = ref.watch(playbackStateProvider).value;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final sleep = ref.watch(sleepTimerProvider).value;
    final accent = Theme.of(context).colorScheme.primary;
    final playing = state?.playing ?? false;
    final shuffle = state?.shuffleMode == AudioServiceShuffleMode.all;
    final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;

    return Scaffold(
      body: GestureDetector(
        onVerticalDragUpdate: (d) =>
            setState(() => _dragY = (_dragY + d.delta.dy).clamp(0, 400)),
        onVerticalDragEnd: _onVerticalEnd,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _dragY == 0 ? 200 : 0),
          transform: Matrix4.translationValues(0, _dragY, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fondo teñido con la portada, como Apple Music.
              AdaptiveBackground(song: song),
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
                          const Expanded(
                            child: Text(
                              'Reproduciendo',
                              textAlign: TextAlign.center,
                              style: TextStyles.overline,
                            ),
                          ),
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
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: _onHorizontalEnd,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = constraints.biggest.shortestSide;
                              return Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  transitionBuilder: (child, animation) {
                                    final slide = Tween(
                                      begin: Offset(0.25 * _swipeDirection, 0),
                                      end: Offset.zero,
                                    ).animate(animation);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: slide,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Artwork(
                                    key: ValueKey(song?.id),
                                    song: song,
                                    size: size,
                                    radius: 32,
                                    highRes: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song?.title ?? 'Nada sonando',
                                  style: TextStyles.display.copyWith(
                                    fontSize: 30,
                                  ),
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
                          if (song != null)
                            HeartButton(songId: song.id, size: 28),
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
                            tooltip: shuffle
                                ? 'Desactivar aleatorio'
                                : 'Aleatorio',
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
          ),
        ),
      ),
    );
  }
}
