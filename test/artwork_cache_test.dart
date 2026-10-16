import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulso_music/data/media_store.dart';
import 'package:pulso_music/ui/common/artwork.dart';

class _FakeMediaStore extends MediaStoreApi {
  _FakeMediaStore(this.covers);

  final Map<int, Uint8List?> covers;
  int calls = 0;

  @override
  Future<Uint8List?> artwork(int songId, {int size = 512}) async {
    calls++;
    return covers[songId];
  }
}

void main() {
  test('peek is unknown until the cover loads, then synchronous', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final cache = ArtworkCache(_FakeMediaStore({1: bytes}));

    expect(cache.peek(1, 256).$1, isFalse);
    await cache.get(1, 256);
    expect(cache.peek(1, 256), (true, bytes));
  });

  test('songs without a cover are remembered as known nulls', () async {
    final api = _FakeMediaStore({});
    final cache = ArtworkCache(api);

    await cache.get(7, 256);
    expect(cache.peek(7, 256), (true, null));
    await cache.get(7, 256);
    expect(api.calls, 1);
  });

  test('evicted entries are no longer peekable', () async {
    final cache = ArtworkCache(_FakeMediaStore({}));
    for (var id = 0; id <= 300; id++) {
      await cache.get(id, 256);
    }
    expect(cache.peek(0, 256).$1, isFalse);
    expect(cache.peek(300, 256).$1, isTrue);
  });
}
