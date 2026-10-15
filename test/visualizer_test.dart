import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulso_music/data/settings.dart';
import 'package:pulso_music/ui/visualizer/edge_geometry.dart';

void main() {
  const size = Size(400, 900);
  final screen = Offset.zero & size;

  group('edgePaths', () {
    test('each position draws the right number of edges', () {
      int count(VisualizerPosition p) => edgePaths(size, 40, p).length;
      expect(count(VisualizerPosition.bottom), 1);
      expect(count(VisualizerPosition.top), 1);
      expect(count(VisualizerPosition.both), 2);
      expect(count(VisualizerPosition.outline), 1);
      expect(count(VisualizerPosition.hidden), 0);
    });

    test('bars always grow into the screen, on every position', () {
      for (final position in VisualizerPosition.values) {
        for (final path in edgePaths(size, 40, position)) {
          final metric = path.computeMetrics().first;
          for (final s in sampleEdge(metric, 20)) {
            final inside = s.point + s.inward * 30;
            expect(
              screen.contains(inside),
              isTrue,
              reason: '$position at ${s.point} points to $inside',
            );
          }
        }
      }
    });

    test('bottom stays at the bottom and top at the top', () {
      final bottom = edgePaths(size, 40, VisualizerPosition.bottom).single;
      final top = edgePaths(size, 40, VisualizerPosition.top).single;
      expect(bottom.getBounds().top, greaterThanOrEqualTo(size.height - 40));
      expect(top.getBounds().bottom, lessThanOrEqualTo(40));
    });

    test('a zero corner radius still works', () {
      final path = edgePaths(size, 0, VisualizerPosition.outline).single;
      expect(path.computeMetrics().first.length, closeTo(2 * (400 + 900), 1));
    });
  });

  group('levelAt', () {
    final levels = [1.0, 0.5, 0.0]; // graves, medios, agudos

    test('bass in the middle of each edge, treble at the ends', () {
      expect(levelAt(0.5, levels), 1.0);
      expect(levelAt(0.0, levels), 0.0);
      expect(levelAt(0.99, levels), closeTo(0.0, 0.01));
    });

    test('mirrored halves match', () {
      expect(levelAt(0.3, levels), levelAt(0.7, levels));
    });

    test('no levels means silence', () {
      expect(levelAt(0.5, const []), 0);
    });
  });

  group('settings', () {
    test('old saved settings map to a position', () {
      expect(
        Settings.fromJson({'visualizerEnabled': true}).visualizerPosition,
        VisualizerPosition.outline,
      );
      expect(
        Settings.fromJson({'visualizerEnabled': false}).visualizerPosition,
        VisualizerPosition.hidden,
      );
    });

    test('new settings round trip and hidden disables it', () {
      const settings = Settings(
        visualizerPosition: VisualizerPosition.both,
        visualizerStyle: VisualizerStyle.dots,
      );
      final back = Settings.fromJson(settings.toJson());
      expect(back.visualizerPosition, VisualizerPosition.both);
      expect(back.visualizerStyle, VisualizerStyle.dots);
      expect(
        settings
            .copyWith(visualizerPosition: VisualizerPosition.hidden)
            .visualizerEnabled,
        isFalse,
      );
    });
  });
}
