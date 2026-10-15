import 'dart:math';
import 'dart:ui';

import '../../data/settings.dart';

/// Trazos del borde donde se dibuja la animación, según la posición elegida.
///
/// Todos van en sentido horario, así la normal "hacia adentro" se obtiene
/// igual en cualquier tramo: girar la tangente 90° (ver [EdgeSample]). Las
/// esquinas usan el radio real de la pantalla para no salirse de ella.
List<Path> edgePaths(Size size, double radius, VisualizerPosition position) {
  final w = size.width;
  final h = size.height;
  final r = min(radius, min(w, h) / 2);
  final corner = Radius.circular(r);

  // Izquierda → derecha por arriba.
  Path top() => Path()
    ..moveTo(0, r)
    ..arcToPoint(Offset(r, 0), radius: corner)
    ..lineTo(w - r, 0)
    ..arcToPoint(Offset(w, r), radius: corner);

  // Derecha → izquierda por abajo (sigue siendo sentido horario).
  Path bottom() => Path()
    ..moveTo(w, h - r)
    ..arcToPoint(Offset(w - r, h), radius: corner)
    ..lineTo(r, h)
    ..arcToPoint(Offset(0, h - r), radius: corner);

  // Contorno completo desde el centro de arriba: a la mitad del recorrido
  // queda el centro de abajo y los dos lados en espejo.
  Path outline() => Path()
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

  return switch (position) {
    VisualizerPosition.bottom => [bottom()],
    VisualizerPosition.top => [top()],
    VisualizerPosition.both => [top(), bottom()],
    VisualizerPosition.outline => [outline()],
    VisualizerPosition.hidden => const [],
  };
}

class EdgeSample {
  const EdgeSample(this.point, this.inward, this.fraction);

  final Offset point;

  /// Unit vector pointing into the screen.
  final Offset inward;

  /// 0..1 along the path.
  final double fraction;
}

Iterable<EdgeSample> sampleEdge(PathMetric metric, double spacing) sync* {
  final count = max(2, (metric.length / spacing).floor());
  for (var i = 0; i < count; i++) {
    final tangent = metric.getTangentForOffset(i * metric.length / count);
    if (tangent == null) continue;
    final dir = tangent.vector;
    yield EdgeSample(tangent.position, Offset(-dir.dy, dir.dx), i / count);
  }
}

/// Band level for a point along a path: mirrored around the middle so both
/// halves match, with the bass at the center of each edge.
double levelAt(double fraction, List<double> levels) {
  if (levels.isEmpty) return 0;
  final mirrored = 1 - (2 * fraction - 1).abs();
  final band = ((1 - mirrored) * (levels.length - 1)).round();
  return levels[band.clamp(0, levels.length - 1)];
}
