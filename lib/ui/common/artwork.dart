import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/media_store.dart';
import '../../data/song.dart';
import '../../state/providers.dart';

/// In-memory LRU cache of artwork bytes, so scrolling doesn't hit MediaStore
/// for every row again.
class ArtworkCache {
  ArtworkCache(this._api);

  static const _capacity = 300;

  final MediaStoreApi _api;
  // Map literals keep insertion order: the first key is the least recent.
  final _entries = <String, Future<Uint8List?>>{};

  Future<Uint8List?> get(int songId, int size) {
    final key = '$songId@$size';
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final future = _api.artwork(songId, size: size).catchError((_) => null);
    _entries[key] = future;
    if (_entries.length > _capacity) _entries.remove(_entries.keys.first);
    return future;
  }
}

final artworkCacheProvider = Provider(
  (ref) => ArtworkCache(ref.watch(mediaStoreProvider)),
);

/// Song cover, or an abstract generated cover when the file has none.
class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    required this.song,
    this.size = 56,
    this.radius = 16,
    this.highRes = false,
  });

  final Song? song;
  final double size;
  final double radius;
  final bool highRes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = this.song;
    final accent = Theme.of(context).colorScheme.primary;
    final fallback = GeneratedCover(seed: song?.id ?? 0, accent: accent);
    Widget child = fallback;
    if (song != null) {
      child = FutureBuilder<Uint8List?>(
        future: ref
            .read(artworkCacheProvider)
            .get(song.id, highRes ? 768 : 256),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return fallback;
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        },
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

/// Deterministic abstract art: same song, same shapes.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({super.key, required this.seed, required this.accent});

  final int seed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = [accent, Palette.coral, Palette.neon, Palette.white];
    final background = colors[seed.abs() % colors.length];
    return CustomPaint(
      painter: _CoverPainter(seed: seed, background: background),
      child: const SizedBox.expand(),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter({required this.seed, required this.background});

  final int seed;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final ink = Palette.on(background);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final s = size.shortestSide;
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;

    switch (random.nextInt(3)) {
      case 0: // círculos concéntricos
        final center = Offset(
          size.width * (0.3 + random.nextDouble() * 0.4),
          size.height * (0.3 + random.nextDouble() * 0.4),
        );
        for (var i = 1; i <= 3; i++) {
          canvas.drawCircle(center, s * 0.12 * i, paint);
        }
      case 1: // onda
        final path = Path()..moveTo(0, size.height * 0.5);
        final waves = 2 + random.nextInt(3);
        for (var x = 0.0; x <= size.width; x += 2) {
          path.lineTo(
            x,
            size.height * 0.5 +
                sin(x / size.width * pi * 2 * waves) * size.height * 0.18,
          );
        }
        canvas.drawPath(path, paint);
      default: // arcos
        for (var i = 0; i < 3; i++) {
          final rect = Rect.fromCircle(
            center: Offset(size.width * random.nextDouble(), size.height),
            radius: s * (0.3 + i * 0.2),
          );
          canvas.drawArc(rect, pi, pi, false, paint);
        }
    }
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.22),
      s * 0.06,
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.seed != seed || old.background != background;
}
