import 'dart:math';

import 'package:flutter/services.dart';

/// Audio bands (0..1) that drive the edge animation.
///
/// The real source is Android's Visualizer attached to ExoPlayer's audio
/// session (VisualizerStreamHandler.kt). Without the microphone permission,
/// or if the device refuses, a simulated source keeps the animation alive in
/// tempo.
class VisualizerSource {
  const VisualizerSource();

  static const bandCount = 48;
  static const _channel = EventChannel('pulso/visualizer');

  Stream<List<double>> real(int audioSessionId) => _channel
      .receiveBroadcastStream(audioSessionId)
      .map((event) => [for (final v in event as List) (v as num).toDouble()]);

  /// ~120 bpm pulse with movement in the mids, at 30 fps.
  Stream<List<double>> simulated() {
    final random = Random();
    final phases = List.generate(
      bandCount,
      (_) => random.nextDouble() * pi * 2,
    );
    return Stream.periodic(const Duration(milliseconds: 33), (tick) {
      final t = tick * 0.033;
      final beat = pow(max(0.0, cos(2 * pi * t * 2)), 6).toDouble();
      return [
        for (var i = 0; i < bandCount; i++)
          _band(i / bandCount, beat, sin(t * (2 + i * 0.15) + phases[i])),
      ];
    });
  }

  static double _band(double position, double beat, double wobble) {
    final bass = beat * (1 - position) * 0.8;
    final motion = 0.18 + 0.14 * wobble;
    return (bass + motion * (1 - position * 0.5)).clamp(0.0, 1.0);
  }
}
