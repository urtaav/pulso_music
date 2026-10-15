import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../audio/visualizer_source.dart';
import '../../data/settings.dart';
import '../../state/providers.dart';

/// Microphone permission, needed by Android's Visualizer. Re-checked with
/// ref.invalidate after asking.
final micPermissionProvider = FutureProvider<bool>(
  (ref) => Permission.microphone.isGranted,
);

final screenCornerRadiusProvider = FutureProvider<double>(
  (ref) => ref.read(mediaStoreProvider).screenCornerRadius(),
);

/// Visualizador que recorre todo el borde de la pantalla.
///
/// Va encima de toda la app (MaterialApp.builder) e ignora los toques. Los
/// datos llegan a ~20-30 Hz desde Android, pero se dibuja a 60 fps: cada frame
/// acerca el valor mostrado al último recibido (sube rápido, baja lento), así
/// se ve fluido y al pausar se apaga suavemente en vez de cortarse.
class EdgeVisualizerOverlay extends ConsumerStatefulWidget {
  const EdgeVisualizerOverlay({super.key});

  @override
  ConsumerState<EdgeVisualizerOverlay> createState() =>
      _EdgeVisualizerOverlayState();
}

class _EdgeVisualizerOverlayState extends ConsumerState<EdgeVisualizerOverlay>
    with SingleTickerProviderStateMixin {
  static const _source = VisualizerSource();

  final _levels = _Levels(VisualizerSource.bandCount);
  late final Ticker _ticker = createTicker(_onTick);
  StreamSubscription<List<double>>? _subscription;
  String? _subscriptionKey;

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    _levels.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final settled = _levels.step();
    // Pausado y ya en reposo: no gastar batería dibujando nada.
    if (settled && _subscription == null) _ticker.stop();
  }

  void _sync({
    required bool active,
    required bool micGranted,
    required int? sessionId,
  }) {
    final useReal = micGranted && (sessionId ?? 0) > 0;
    final key = !active ? null : (useReal ? 'real:$sessionId' : 'sim');
    if (key == _subscriptionKey) return;
    _subscriptionKey = key;
    _subscription?.cancel();
    _subscription = null;

    if (key == null) {
      _levels.target.fillRange(0, _levels.target.length, 0);
    } else {
      final stream = useReal ? _source.real(sessionId!) : _source.simulated();
      _subscription = stream.listen(
        _levels.setTarget,
        // Sin acceso real (permiso revocado, sesión ocupada): animación simulada.
        onError: (_) {
          _subscription?.cancel();
          _subscription = _source.simulated().listen(_levels.setTarget);
        },
      );
    }
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final playing = ref.watch(isPlayingProvider);
    final micGranted = ref.watch(micPermissionProvider).value ?? false;
    final sessionId = ref.watch(audioSessionIdProvider).value;
    final corner = ref.watch(screenCornerRadiusProvider).value ?? 0;

    _sync(
      active: playing && settings.visualizerEnabled,
      micGranted: micGranted,
      sessionId: sessionId,
    );

    if (!settings.visualizerEnabled && !_ticker.isActive) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _EdgePainter(
            levels: _levels,
            style: settings.visualizerStyle,
            intensity: settings.visualizerIntensity,
            color: Color(settings.accent),
            cornerRadius: corner,
          ),
        ),
      ),
    );
  }
}

/// Smoothed band levels; notifies the painter on each frame.
class _Levels extends ChangeNotifier {
  _Levels(int count)
    : current = List.filled(count, 0),
      target = List.filled(count, 0);

  final List<double> current;
  final List<double> target;

  void setTarget(List<double> values) {
    for (var i = 0; i < target.length && i < values.length; i++) {
      target[i] = values[i];
    }
  }

  /// Returns true when everything is at rest near zero.
  bool step() {
    var settled = true;
    for (var i = 0; i < current.length; i++) {
      final diff = target[i] - current[i];
      current[i] += diff * (diff > 0 ? 0.45 : 0.12);
      if (current[i] > 0.002 || target[i] > 0) settled = false;
    }
    notifyListeners();
    return settled;
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required _Levels levels,
    required this.style,
    required this.intensity,
    required this.color,
    required this.cornerRadius,
  }) : _levels = levels,
       super(repaint: levels);

  final _Levels _levels;
  final VisualizerStyle style;
  final double intensity;
  final Color color;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final levels = _levels.current;
    if (levels.every((v) => v < 0.002)) return;

    final outline = _outline(size, cornerRadius);
    final metric = outline.computeMetrics().first;

    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, metric, levels);
      case VisualizerStyle.pulse:
        _paintPulse(canvas, outline, levels);
      case VisualizerStyle.wave:
        _paintWave(canvas, metric, levels);
    }
  }

  /// Contorno exacto de la pantalla con el radio real de sus esquinas. Empieza
  /// en el centro de arriba y va en sentido horario, así la mitad del
  /// recorrido cae en el centro de abajo y ambos lados quedan en espejo.
  static Path _outline(Size size, double radius) {
    final w = size.width;
    final h = size.height;
    final r = min(radius, min(w, h) / 2);
    final corner = Radius.circular(r);
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: corner)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: corner)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: corner)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: corner)
      ..close();
  }

  /// Band for a point along the outline (0 = top center), mirrored left/right
  /// so both sides move together. Bass sits at the bottom.
  double _levelAt(double fraction, List<double> levels) {
    final mirrored = 1 - (2 * fraction - 1).abs();
    final band = ((1 - mirrored) * (levels.length - 1)).round();
    return levels[band];
  }

  Iterable<({Offset point, Offset inward, double level})> _samples(
    PathMetric metric,
    List<double> levels,
    double spacing,
  ) sync* {
    final count = (metric.length / spacing).floor();
    for (var i = 0; i < count; i++) {
      final tangent = metric.getTangentForOffset(i * spacing);
      if (tangent == null) continue;
      final dir = tangent.vector;
      yield (
        point: tangent.position,
        // El trazo va en sentido horario: girar la tangente apunta hacia adentro.
        inward: Offset(-dir.dy, dir.dx),
        level: _levelAt(i / count, levels),
      );
    }
  }

  void _paintBars(Canvas canvas, PathMetric metric, List<double> levels) {
    const spacing = 7.0;
    final maxLength = 64 * intensity;
    final paint = Paint()
      ..strokeWidth = spacing * 0.55
      ..strokeCap = StrokeCap.round;
    for (final s in _samples(metric, levels, spacing)) {
      if (s.level < 0.02) continue;
      paint.color = color.withValues(alpha: 0.25 + 0.4 * s.level);
      canvas.drawLine(
        s.point,
        s.point + s.inward * (maxLength * s.level),
        paint,
      );
    }
  }

  void _paintPulse(Canvas canvas, Path outline, List<double> levels) {
    // Los graves (primeras bandas) mueven el "cono de la bocina".
    final bass = levels.take(6).reduce((a, b) => a + b) / 6;
    final width = (24 + 150 * bass) * intensity;
    for (final (blur, alpha) in [(40.0, 0.35), (16.0, 0.4), (4.0, 0.5)]) {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * (blur / 40 + 0.4)
          ..color = color.withValues(alpha: alpha * (0.3 + 0.7 * bass))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  void _paintWave(Canvas canvas, PathMetric metric, List<double> levels) {
    final maxLength = 48 * intensity;
    final path = Path();
    var first = true;
    for (final s in _samples(metric, levels, 5)) {
      final p = s.point + s.inward * (4 + maxLength * s.level);
      if (first) {
        path.moveTo(p.dx, p.dy);
        first = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.style != style ||
      old.intensity != intensity ||
      old.color != color ||
      old.cornerRadius != cornerRadius;
}

/// Explains why the microphone is needed before asking for it.
Future<void> askVisualizerPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Animación con tu música'),
      content: const Text(
        'Para que los bordes de la pantalla se muevan con lo que suena, '
        'Android pide el permiso de micrófono. pulso no graba ni escucha '
        'tu entorno: solo lee el audio que la propia app está reproduciendo.\n\n'
        'Si no lo das, la animación seguirá funcionando en modo simulado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Permitir'),
        ),
      ],
    ),
  );
  ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(askedVisualizerPermission: true));
  if (accepted != true) return;
  final status = await Permission.microphone.request();
  if (status.isPermanentlyDenied) await openAppSettings();
  ref.invalidate(micPermissionProvider);
}
