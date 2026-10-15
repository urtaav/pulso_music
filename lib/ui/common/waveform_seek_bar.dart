import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';

/// Decorative waveform that doubles as a draggable progress bar.
///
/// The bar heights are generated from the song id (not decoded from the
/// file), so each song has its own recognizable shape at no cost.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.color,
    this.height = 56,
  });

  final int seed;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color color;
  final double height;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  double? _dragFraction;

  double get _fraction {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _drag(Offset local, double width) {
    setState(() => _dragFraction = (local.dx / width).clamp(0.0, 1.0));
  }

  void _commit() {
    final fraction = _dragFraction;
    if (fraction == null) return;
    widget.onSeek(widget.duration * fraction);
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _dragFraction ?? _fraction;
    final shown = _dragFraction != null
        ? widget.duration * _dragFraction!
        : widget.position;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Semantics(
              slider: true,
              label: 'Progreso',
              value: formatDuration(shown),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => _drag(d.localPosition, width),
                onHorizontalDragUpdate: (d) => _drag(d.localPosition, width),
                onHorizontalDragEnd: (_) => _commit(),
                onTapDown: (d) => _drag(d.localPosition, width),
                onTapUp: (_) => _commit(),
                child: CustomPaint(
                  size: Size(width, widget.height),
                  painter: _WavePainter(
                    seed: widget.seed,
                    fraction: fraction,
                    color: widget.color,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatDuration(shown),
              style: TextStyles.numbers.copyWith(color: Palette.white),
            ),
            Text(formatDuration(widget.duration), style: TextStyles.numbers),
          ],
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.seed,
    required this.fraction,
    required this.color,
  });

  static const _bars = 64;

  final int seed;
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final step = size.width / _bars;
    final barWidth = step * 0.55;
    final played = Paint()..color = color;
    final pending = Paint()..color = Palette.cardHigh;

    for (var i = 0; i < _bars; i++) {
      // Envolvente suave + ruido: parece una canción real, no ruido blanco.
      final envelope = 0.35 + 0.65 * sin(pi * (i + 0.5) / _bars);
      final h = size.height * envelope * (0.3 + 0.7 * random.nextDouble());
      final x = i * step + (step - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, (i + 0.5) / _bars <= fraction ? played : pending);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.fraction != fraction || old.seed != seed || old.color != color;
}
