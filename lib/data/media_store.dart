import 'package:flutter/services.dart';

import 'song.dart';

/// Bridge to the native MediaStore code in MainActivity.kt.
class MediaStoreApi {
  const MediaStoreApi();

  static const _channel = MethodChannel('pulso/media');

  Future<List<Song>> scan() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('scan');
    return [for (final map in raw ?? const []) Song.fromMap(map)];
  }

  Future<Uint8List?> artwork(int songId, {int size = 512}) =>
      _channel.invokeMethod<Uint8List>('artwork', {'id': songId, 'size': size});

  /// Physical corner radius of the screen in logical pixels (0 if unknown).
  Future<double> screenCornerRadius() async =>
      await _channel.invokeMethod<double>('screenCornerRadius') ?? 0;

  /// Widget button pressed while the app was closed, if any.
  Future<String?> consumeLaunchAction() =>
      _channel.invokeMethod<String>('consumeLaunchAction');
}
