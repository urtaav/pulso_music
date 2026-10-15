import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/play_pause_button.dart';
import 'player_screen.dart';

/// Fixed above the navigation bar; tap or swipe up to open the full player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();
    final playing = ref.watch(isPlayingProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final handler = ref.read(audioHandlerProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final total = song.duration.inMilliseconds;
    final progress = total <= 0 ? 0.0 : position.inMilliseconds / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: GestureDetector(
        onTap: () => openPlayer(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) openPlayer(context);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Row(
                  children: [
                    Artwork(song: song, size: 48, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: handler.skipToNext,
                    ),
                    PlayPauseButton(
                      playing: playing,
                      onPressed: handler.togglePlay,
                      size: 48,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 2,
                color: accent,
                backgroundColor: Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
