import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso_music/ui/common/artwork_palette.dart';

Uint8List pixels(List<(int, int, int)> colors) => Uint8List.fromList([
  for (final (r, g, b) in colors) ...[r, g, b, 255],
]);

void main() {
  test('a saturated color wins over grey and black', () {
    final color = dominantColor(
      pixels([
        (230, 40, 60), // rojo
        (230, 40, 60),
        (128, 128, 128),
        (0, 0, 0),
        (0, 0, 0),
        (0, 0, 0),
      ]),
    );
    expect(color.r * 255, greaterThan(150));
    expect(color.g * 255, lessThan(100));
  });

  test('a fully transparent image falls back', () {
    final transparent = Uint8List.fromList([10, 10, 10, 0, 20, 20, 20, 0]);
    expect(dominantColor(transparent), ArtworkPalette.fallback.dominant);
  });

  test('background stays dark but keeps the hue', () {
    const palette = ArtworkPalette(dominant: Color(0xFF3060F0));
    final hsl = HSLColor.fromColor(palette.background);
    expect(hsl.lightness, lessThanOrEqualTo(0.16));
    expect(hsl.hue, closeTo(HSLColor.fromColor(palette.dominant).hue, 1));
  });

  test('a white cover still gives a dark background', () {
    const palette = ArtworkPalette(dominant: Color(0xFFFFFFFF));
    expect(HSLColor.fromColor(palette.background).lightness, lessThan(0.2));
  });
}
