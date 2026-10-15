import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/artwork_palette.dart';
import '../common/glass.dart';
import 'player_screen.dart';

/// Glass capsule with the current song; tap or swipe up for the full player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.height = 64});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();
    final playing = ref.watch(isPlayingProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final palette = ref.watch(stablePaletteProvider);
    final handler = ref.read(audioHandlerProvider);
    final total = song.duration.inMilliseconds;
    final progress = total <= 0 ? 0.0 : position.inMilliseconds / total;

    return Semantics(
      button: true,
      label: 'Abrir reproductor: ${song.title}, ${song.artist}',
      child: GestureDetector(
        onTap: () => openPlayer(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) openPlayer(context);
        },
        child: GlassSurface(
          radius: height / 2,
          tint: palette.tint,
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                  child: Row(
                    children: [
                      Artwork(song: song, size: height - 20, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.caption.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: playing ? 'Pausar' : 'Reproducir',
                        iconSize: 32,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(playing),
                          ),
                        ),
                        onPressed: handler.togglePlay,
                      ),
                      IconButton(
                        tooltip: 'Siguiente',
                        iconSize: 28,
                        icon: const Icon(Icons.fast_forward_rounded),
                        onPressed: handler.skipToNext,
                      ),
                    ],
                  ),
                ),
                // Progreso mínimo en el borde inferior de la cápsula.
                Positioned(
                  left: height / 2,
                  right: height / 2,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 2,
                      color: Palette.white.withValues(alpha: 0.85),
                      backgroundColor: Palette.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
