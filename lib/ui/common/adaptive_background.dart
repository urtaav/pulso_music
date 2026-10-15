import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song.dart';
import 'artwork.dart';
import 'artwork_palette.dart';

/// Background tinted by the cover: the artwork heavily blurred over its
/// dominant color, fading into near-black so text always stays readable.
class AdaptiveBackground extends ConsumerWidget {
  const AdaptiveBackground({
    super.key,
    required this.song,
    this.palette,
    this.intensity = 1,
  });

  final Song? song;

  /// Defaults to the palette of the song that's playing.
  final ArtworkPalette? palette;

  /// 0..1, how much of the cover shows through.
  final double intensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArtworkPalette colors = palette ?? ref.watch(stablePaletteProvider);
    final song = this.song;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          color: colors.background,
        ),
        if (song != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: FutureBuilder<Uint8List?>(
              key: ValueKey(song.id),
              future: ref.read(artworkCacheProvider).get(song.id, 256),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return const SizedBox.expand();
                return Opacity(
                  opacity: 0.55 * intensity,
                  // Desenfoque fuerte: solo quedan manchas de color, como en iOS.
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 60,
                      sigmaY: 60,
                      tileMode: TileMode.mirror,
                    ),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                );
              },
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Oscurece sin borrar el color: el texto se lee y el tinte se nota.
              colors: [Color(0x26000000), Color(0x73000000), Color(0xB30A0A0B)],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
      ],
    );
  }
}
