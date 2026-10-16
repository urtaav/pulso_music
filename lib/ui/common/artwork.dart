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
  // Lo que ya llegó, para pintarlo en el mismo frame: con solo el Future,
  // FutureBuilder dibuja un frame vacío y la portada parpadea al hacer scroll.
  final _resolved = <String, Uint8List?>{};

  Future<Uint8List?> get(int songId, int size) {
    final key = '$songId@$size';
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final future = _api
        .artwork(songId, size: size)
        .catchError((_) => null)
        .then((bytes) {
          if (_entries.containsKey(key)) _resolved[key] = bytes;
          return bytes;
        });
    _entries[key] = future;
    if (_entries.length > _capacity) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      _resolved.remove(oldest);
    }
    return future;
  }

  /// `(true, bytes)` once loaded (bytes is null when the song has no cover),
  /// `(false, null)` while still unknown.
  (bool, Uint8List?) peek(int songId, int size) {
    final key = '$songId@$size';
    return _resolved.containsKey(key) ? (true, _resolved[key]) : (false, null);
  }
}

final artworkCacheProvider = Provider(
  (ref) => ArtworkCache(ref.watch(mediaStoreProvider)),
);

/// Song cover, or an elegant generated cover when the file has none.
class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    required this.song,
    this.size = 56,
    this.radius = 16,
    this.highRes = false,
    this.fill = false,
  });

  final Song? song;
  final double size;
  final double radius;
  final bool highRes;

  /// Ignores [size] and fills the parent (full-screen hero images).
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = this.song;
    final placeholder = GeneratedCover(song: song);
    Widget child = placeholder;
    if (song != null) {
      final cache = ref.read(artworkCacheProvider);
      final resolution = highRes ? 768 : 256;
      final (known, bytes) = cache.peek(song.id, resolution);
      // Decodificar al tamaño en pantalla: menos trabajo por frame al hacer scroll.
      final decodeWidth = fill
          ? null
          : (size * MediaQuery.devicePixelRatioOf(context)).round();
      if (known) {
        child = bytes == null
            ? placeholder
            : _CoverImage(bytes: bytes, decodeWidth: decodeWidth);
      } else {
        child = FutureBuilder<Uint8List?>(
          future: cache.get(song.id, resolution),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(color: Palette.card);
            }
            final bytes = snapshot.data;
            return _FadeIn(
              child: bytes == null
                  ? placeholder
                  : _CoverImage(bytes: bytes, decodeWidth: decodeWidth),
            );
          },
        );
      }
    }
    final box = fill
        ? SizedBox.expand(child: child)
        : SizedBox.square(dimension: size, child: child);
    if (radius == 0) return box;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: box);
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.bytes, required this.decodeWidth});

  final Uint8List bytes;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: decodeWidth,
      filterQuality: FilterQuality.medium,
      // La primera decodificación es asíncrona: aparece con un fundido corto
      // en vez de un salto. Si ya estaba decodificada, sale directo.
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, _, _) => const ColoredBox(color: Palette.card),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

/// Cover for songs without artwork: a deep two-tone gradient with a soft
/// glow and the album's initial. Same album, same cover.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({super.key, required this.song});

  final Song? song;

  // Pares oscuros y saturados: se ven bien junto a portadas reales.
  static const _gradients = [
    [Color(0xFF3A1C71), Color(0xFFD76D77)],
    [Color(0xFF0F2027), Color(0xFF2C5364)],
    [Color(0xFF1D2B64), Color(0xFF8E54E9)],
    [Color(0xFF42275A), Color(0xFF734B6D)],
    [Color(0xFF134E5E), Color(0xFF71B280)],
    [Color(0xFF2B1B17), Color(0xFFC0623C)],
    [Color(0xFF16222A), Color(0xFF3A6073)],
    [Color(0xFF41295A), Color(0xFF2F0743)],
    [Color(0xFF1F1C2C), Color(0xFF928DAB)],
    [Color(0xFF3D0C11), Color(0xFFB2333F)],
  ];

  /// Gradient used for [song]; also tints the background when it plays.
  static List<Color> colorsFor(Song? song) =>
      _gradients[_key(song).hashCode.abs() % _gradients.length];

  static String _key(Song? song) {
    if (song == null) return '';
    return song.album == 'Sin álbum' ? song.title : song.album;
  }

  @override
  Widget build(BuildContext context) {
    final key = _key(song).trim();
    final initial = key.isEmpty
        ? null
        : String.fromCharCode(key.runes.first).toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colorsFor(song),
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.7),
            radius: 1.1,
            colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            return Center(
              child: initial == null
                  ? Icon(
                      Icons.music_note_rounded,
                      size: side * 0.36,
                      color: Palette.white.withValues(alpha: 0.75),
                    )
                  : Text(
                      initial,
                      textScaler: TextScaler.noScaling,
                      style: TextStyles.display.copyWith(
                        fontSize: side * 0.46,
                        height: 1,
                        letterSpacing: -side * 0.02,
                        color: Palette.white.withValues(alpha: 0.85),
                        shadows: const [
                          Shadow(color: Color(0x40000000), blurRadius: 24),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
