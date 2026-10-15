import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../audio/visualizer_source.dart';
import '../../data/settings.dart';
import '../../state/providers.dart';
import 'edge_geometry.dart';

/// Microphone permission, needed by Android's Visualizer. Re-checked with
/// ref.invalidate after asking.
final micPermissionProvider = FutureProvider<bool>(
  (ref) => Permission.microphone.isGranted,
);

final screenCornerRadiusProvider = FutureProvider<double>(
  (ref) => ref.read(mediaStoreProvider).screenCornerRadius(),
);

/// Visualizador pegado al borde de la pantalla.
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

  final _levels = VisualizerLevels(VisualizerSource.bandCount);
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

  void _onTick(Duration elapsed) {
    final settled = _levels.step(elapsed);
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
      _levels.clearTarget();
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
    if (!_ticker.isActive) {
      _levels.resetClock();
      _ticker.start();
    }
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
          painter: EdgePainter(
            levels: _levels,
            style: settings.visualizerStyle,
            // Al ocultarla, termina de apagarse en el último lugar que tenía.
            position: settings.visualizerEnabled
                ? settings.visualizerPosition
                : VisualizerPosition.outline,
            intensity: settings.visualizerIntensity,
            color: Color(settings.accent),
            cornerRadius: corner,
          ),
        ),
      ),
    );
  }
}

/// Live preview for Settings, fed by the simulated source.
class VisualizerPreview extends ConsumerStatefulWidget {
  const VisualizerPreview({super.key, this.height = 170});

  final double height;

  @override
  ConsumerState<VisualizerPreview> createState() => _VisualizerPreviewState();
}

class _VisualizerPreviewState extends ConsumerState<VisualizerPreview>
    with SingleTickerProviderStateMixin {
  final _levels = VisualizerLevels(VisualizerSource.bandCount);
  late final Ticker _ticker = createTicker(_levels.step);
  late final StreamSubscription<List<double>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = const VisualizerSource().simulated().listen(
      _levels.setTarget,
    );
    _ticker.start();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _ticker.dispose();
    _levels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Semantics(
      label: 'Vista previa de la animación',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: widget.height,
          color: const Color(0xFF121214),
          child: settings.visualizerEnabled
              ? CustomPaint(
                  size: Size.infinite,
                  painter: EdgePainter(
                    levels: _levels,
                    style: settings.visualizerStyle,
                    position: settings.visualizerPosition,
                    intensity: settings.visualizerIntensity * 0.7,
                    color: Color(settings.accent),
                    cornerRadius: 28,
                  ),
                )
              : const Center(
                  child: Text('Animación oculta', style: TextStyles.caption),
                ),
        ),
      ),
    );
  }
}

/// Smoothed band levels; notifies the painter on each frame.
class VisualizerLevels extends ChangeNotifier {
  VisualizerLevels(int count)
    : current = List.filled(count, 0),
      target = List.filled(count, 0);

  final List<double> current;
  final List<double> target;

  void setTarget(List<double> values) {
    for (var i = 0; i < target.length && i < values.length; i++) {
      target[i] = values[i];
    }
  }

  void clearTarget() => target.fillRange(0, target.length, 0);

  // Constantes de tiempo del suavizado: subir rápido y bajar lento se siente
  // como un medidor real; bajar rápido es lo que se veía brusco.
  static const _riseSeconds = 0.07;
  static const _fallSeconds = 0.32;

  Duration? _lastFrame;

  /// Advances the smoothing to [now]; returns true when everything is at rest.
  ///
  /// Depende del tiempo real entre frames y no del número de frames, así se
  /// ve igual a 60 o 120 Hz y no salta si se pierde un frame.
  bool step(Duration now) {
    final last = _lastFrame;
    _lastFrame = now;
    final dt = last == null
        ? 1 / 60
        : ((now - last).inMicroseconds / 1e6).clamp(0.0, 0.1);

    final riseK = 1 - math.exp(-dt / _riseSeconds);
    final fallK = 1 - math.exp(-dt / _fallSeconds);
    var settled = true;
    for (var i = 0; i < current.length; i++) {
      // Promedio con las bandas vecinas: el borde ondula en vez de tener
      // barras sueltas que brincan solas.
      final left = target[math.max(0, i - 1)];
      final right = target[math.min(target.length - 1, i + 1)];
      final goal = target[i] * 0.6 + (left + right) * 0.2;
      final diff = goal - current[i];
      current[i] += diff * (diff > 0 ? riseK : fallK);
      if (current[i] > 0.002 || target[i] > 0) settled = false;
    }
    notifyListeners();
    return settled;
  }

  /// Restarts the clock so a pause doesn't count as one huge frame.
  void resetClock() => _lastFrame = null;
}

class EdgePainter extends CustomPainter {
  EdgePainter({
    required VisualizerLevels levels,
    required this.style,
    required this.position,
    required this.intensity,
    required this.color,
    required this.cornerRadius,
  }) : _levels = levels,
       super(repaint: levels);

  final VisualizerLevels _levels;
  final VisualizerStyle style;
  final VisualizerPosition position;
  final double intensity;
  final Color color;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final levels = _levels.current;
    if (levels.every((v) => v < 0.002)) return;

    // Un solo borde tiene más espacio para crecer que el contorno completo.
    final maxLength =
        (position == VisualizerPosition.outline ? 56.0 : 84.0) * intensity;

    for (final path in edgePaths(size, cornerRadius, position)) {
      final metric = path.computeMetrics().first;
      switch (style) {
        case VisualizerStyle.bars:
          _bars(canvas, metric, levels, maxLength);
        case VisualizerStyle.mirror:
          _mirror(canvas, metric, levels, maxLength);
        case VisualizerStyle.dots:
          _dots(canvas, metric, levels, maxLength);
        case VisualizerStyle.lines:
          _lines(canvas, metric, levels, maxLength);
        case VisualizerStyle.wave:
          _wave(canvas, metric, levels, maxLength, closed: metric.isClosed);
        case VisualizerStyle.pulse:
          _pulse(canvas, path, levels);
      }
    }
  }

  /// Barras que nacen del borde hacia adentro.
  void _bars(
    Canvas canvas,
    PathMetric metric,
    List<double> levels,
    double max,
  ) {
    const spacing = 7.0;
    final paint = Paint()
      ..strokeWidth = spacing * 0.55
      ..strokeCap = StrokeCap.round;
    for (final s in sampleEdge(metric, spacing)) {
      final v = levelAt(s.fraction, levels);
      if (v < 0.02) continue;
      paint.color = color.withValues(alpha: 0.25 + 0.4 * v);
      canvas.drawLine(s.point, s.point + s.inward * (max * v), paint);
    }
  }

  /// Espectro espejo: barras centradas en una línea paralela al borde que
  /// crecen hacia ambos lados, como un ecualizador clásico.
  void _mirror(
    Canvas canvas,
    PathMetric metric,
    List<double> levels,
    double max,
  ) {
    const spacing = 6.0;
    final base = max * 0.55 + 6;
    final paint = Paint()
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    for (final s in sampleEdge(metric, spacing)) {
      final v = levelAt(s.fraction, levels);
      final half = 1.5 + max * 0.5 * v;
      final center = s.point + s.inward * base;
      paint.color = color.withValues(alpha: 0.2 + 0.5 * v);
      canvas.drawLine(
        center - s.inward * half,
        center + s.inward * half,
        paint,
      );
    }
  }

  /// Columnas de puntos tipo matriz (Nothing): se encienden según el nivel y
  /// los apagados quedan como puntos tenues.
  void _dots(
    Canvas canvas,
    PathMetric metric,
    List<double> levels,
    double max,
  ) {
    const spacing = 11.0;
    const step = 8.0;
    final rows = (max / step).floor().clamp(3, 10);
    final lit = <Offset>[];
    final unlit = <Offset>[];
    for (final s in sampleEdge(metric, spacing)) {
      final on = (levelAt(s.fraction, levels) * rows).round();
      for (var k = 0; k < rows; k++) {
        (k < on ? lit : unlit).add(s.point + s.inward * (6 + k * step));
      }
    }
    final dot = Paint()
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(
      PointMode.points,
      unlit,
      dot..color = Palette.white.withValues(alpha: 0.06),
    );
    canvas.drawPoints(
      PointMode.points,
      lit,
      dot
        ..color = Color.lerp(
          color,
          Palette.white,
          0.25,
        )!.withValues(alpha: 0.8),
    );
  }

  /// Líneas finas y densas con brillo suave, como las de los widgets.
  void _lines(
    Canvas canvas,
    PathMetric metric,
    List<double> levels,
    double max,
  ) {
    final path = Path();
    for (final s in sampleEdge(metric, 4)) {
      final v = levelAt(s.fraction, levels);
      if (v < 0.03) continue;
      final end = s.point + s.inward * (max * 0.9 * v);
      path
        ..moveTo(s.point.dx, s.point.dy)
        ..lineTo(end.dx, end.dy);
    }
    final light = Color.lerp(color, Palette.white, 0.55)!;
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = light.withValues(alpha: 0.75),
      );
  }

  void _wave(
    Canvas canvas,
    PathMetric metric,
    List<double> levels,
    double max, {
    required bool closed,
  }) {
    final path = Path();
    var first = true;
    for (final s in sampleEdge(metric, 5)) {
      final v = levelAt(s.fraction, levels);
      final p = s.point + s.inward * (4 + max * 0.85 * v);
      if (first) {
        path.moveTo(p.dx, p.dy);
        first = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (closed) path.close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.75),
      );
  }

  /// Resplandor que late con los graves, como la membrana de una bocina.
  void _pulse(Canvas canvas, Path path, List<double> levels) {
    final bass = levels.take(6).reduce((a, b) => a + b) / 6;
    final width = (24 + 150 * bass) * intensity;
    for (final (blur, alpha) in [(40.0, 0.35), (16.0, 0.4), (4.0, 0.5)]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * (blur / 40 + 0.4)
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: alpha * (0.3 + 0.7 * bass))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  @override
  bool shouldRepaint(EdgePainter old) =>
      old.style != style ||
      old.position != position ||
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
