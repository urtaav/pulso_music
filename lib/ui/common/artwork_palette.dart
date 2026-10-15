import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'artwork.dart';

/// Colors derived from the current cover, for adaptive backgrounds.
class ArtworkPalette {
  const ArtworkPalette({required this.dominant});

  static const fallback = ArtworkPalette(dominant: Color(0xFF2A2A30));

  final Color dominant;

  /// Deep version of the dominant color: dark first, but still tinted.
  Color get background {
    final hsl = HSLColor.fromColor(dominant);
    return hsl
        .withLightness(hsl.lightness.clamp(0.08, 0.16))
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 0.6))
        .toColor();
  }

  /// Lighter tint for glass surfaces and highlights.
  Color get tint {
    final hsl = HSLColor.fromColor(dominant);
    return hsl.withLightness(hsl.lightness.clamp(0.35, 0.6)).toColor();
  }
}

/// Picks the dominant color from raw RGBA pixels.
///
/// Plain averaging turns most covers into mud, so each pixel is weighted by
/// its saturation and penalized when nearly black or white.
Color dominantColor(Uint8List rgba) {
  double r = 0, g = 0, b = 0, total = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final alpha = rgba[i + 3] / 255;
    if (alpha < 0.5) continue;
    final pr = rgba[i] / 255, pg = rgba[i + 1] / 255, pb = rgba[i + 2] / 255;
    final maxC = [pr, pg, pb].reduce((a, c) => a > c ? a : c);
    final minC = [pr, pg, pb].reduce((a, c) => a < c ? a : c);
    final lightness = (maxC + minC) / 2;
    final saturation = maxC == minC
        ? 0.0
        : (maxC - minC) / (1 - (2 * lightness - 1).abs());
    final extremes = lightness < 0.08 || lightness > 0.92 ? 0.15 : 1.0;
    final weight = (0.15 + saturation) * extremes;
    r += pr * weight;
    g += pg * weight;
    b += pb * weight;
    total += weight;
  }
  if (total == 0) return ArtworkPalette.fallback.dominant;
  return Color.fromARGB(
    255,
    (r / total * 255).round(),
    (g / total * 255).round(),
    (b / total * 255).round(),
  );
}

Future<ArtworkPalette> paletteFromBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 16,
    targetHeight: 16,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  if (data == null) return ArtworkPalette.fallback;
  return ArtworkPalette(dominant: dominantColor(data.buffer.asUint8List()));
}

/// Palette of the song that's playing; generated covers fall back to accent.
final currentPaletteProvider = FutureProvider<ArtworkPalette>((ref) async {
  final song = ref.watch(currentSongProvider);
  final accent = Color(ref.watch(settingsProvider.select((s) => s.accent)));
  if (song == null) return ArtworkPalette.fallback;
  final bytes = await ref.read(artworkCacheProvider).get(song.id, 256);
  if (bytes == null) return ArtworkPalette(dominant: accent);
  try {
    return await paletteFromBytes(bytes);
  } on Exception {
    return ArtworkPalette(dominant: accent);
  }
});

/// Last palette that finished loading. While the next one loads Riverpod
/// keeps the previous value, so backgrounds don't flash grey between songs.
final stablePaletteProvider = Provider<ArtworkPalette>(
  (ref) => ref.watch(currentPaletteProvider).value ?? ArtworkPalette.fallback,
);
