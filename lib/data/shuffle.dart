import 'dart:math';

import 'song.dart';

/// Songs heard in the current cycle, persisted so the cycle survives restarts.
///
/// Cualquier canción que empieza a sonar cuenta como escuchada, sin importar
/// cómo se eligió; así el aleatorio prioriza lo que de verdad no has oído.
class ShuffleHistory {
  ShuffleHistory({required Set<int> played, required this.save})
    : _played = {...played};

  final Set<int> _played;
  final Future<void> Function(Set<int> played) save;

  Set<int> get played => Set.unmodifiable(_played);

  void markPlayed(int songId) {
    if (_played.add(songId)) save(_played);
  }

  /// Starts a new cycle for these songs only; other collections keep theirs.
  void forget(Iterable<int> songIds) {
    final before = _played.length;
    _played.removeAll(songIds);
    if (_played.length != before) save(_played);
  }
}

class ShuffleOrder {
  const ShuffleOrder(this.songs, {required this.startedNewCycle});

  final List<Song> songs;

  /// True when every song had already played, so the cycle starts over.
  final bool startedNewCycle;
}

/// Orden aleatorio sin repeticiones.
///
/// Primero todo lo que no ha sonado en el ciclo, luego lo que ya sonó; cada
/// grupo mezclado y sin el mismo artista dos veces seguidas. Si todo ya sonó,
/// empieza un ciclo nuevo con la colección completa.
ShuffleOrder shuffleWithoutRepeats(
  List<Song> songs,
  Set<int> played,
  Random random,
) {
  final fresh = songs.where((s) => !played.contains(s.id)).toList();
  if (fresh.isEmpty) {
    return ShuffleOrder(
      spreadArtists([...songs]..shuffle(random)),
      startedNewCycle: songs.isNotEmpty,
    );
  }
  final heard = songs.where((s) => played.contains(s.id)).toList();
  return ShuffleOrder([
    ...spreadArtists(fresh..shuffle(random)),
    ...spreadArtists(heard..shuffle(random)),
  ], startedNewCycle: false);
}

/// Reorders so the same artist doesn't play twice in a row whenever that's
/// possible, keeping the incoming (already shuffled) order as much as it can.
///
/// Se arma la lista paso a paso tomando la primera canción de otro artista.
/// Si a un artista le quedan tantas canciones que después ya no se podrían
/// intercalar, se le da prioridad; sin eso se juntan al final de la lista.
List<Song> spreadArtists(List<Song> songs) {
  final remaining = [...songs];
  final left = <String, int>{};
  for (final s in songs) {
    left[s.artist] = (left[s.artist] ?? 0) + 1;
  }
  final result = <Song>[];

  while (remaining.isNotEmpty) {
    final last = result.isEmpty ? null : result.last.artist;
    String? urgent;
    for (final entry in left.entries) {
      // Con c canciones de un artista y n en total, hace falta al menos c-1
      // canciones de otros entre ellas.
      if (entry.key != last && entry.value * 2 > remaining.length) {
        urgent = entry.key;
      }
    }
    var index = remaining.indexWhere(
      (s) => urgent != null ? s.artist == urgent : s.artist != last,
    );
    if (index == -1) index = 0; // Solo queda el mismo artista: no hay arreglo.
    final next = remaining.removeAt(index);
    left[next.artist] = left[next.artist]! - 1;
    result.add(next);
  }
  return result;
}
