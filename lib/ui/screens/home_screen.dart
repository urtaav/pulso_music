import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/library.dart';
import '../../state/providers.dart';
import '../common/glass.dart';
import '../common/pressable.dart';
import '../common/sections.dart';
import '../common/song_tile.dart';
import '../common/week_chart.dart';
import 'collection_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final library = ref.watch(libraryValueProvider);
    final recents = library.resolve(ref.watch(recentsProvider));
    final favorites = ref.watch(favoritesProvider);
    final handler = ref.read(audioHandlerProvider);
    final recentlyAdded = library.recentlyAdded.take(6).toList();
    final albumsForYou = _albumsOfTheDay(library);
    final topSongs = ref.watch(topSongsProvider);
    final week = ref.watch(weekSummaryProvider);
    final loading = libraryState.isLoading && library.songs.isEmpty;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomInset(context)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
            child: Text(greetingFor(DateTime.now()), style: TextStyles.display),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              loading
                  ? 'Buscando tu música…'
                  : '${library.songs.length} canciones · '
                        '${library.albums.length} álbumes',
              style: TextStyles.caption,
            ),
          ),
          const SizedBox(height: 20),
          if (!libraryState.isLoading && library.songs.isEmpty)
            _EmptyLibrary(
              onRescan: () => ref.read(scannedSongsProvider.notifier).refresh(),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      label: 'Aleatorio',
                      icon: Icons.shuffle_rounded,
                      onTap: () =>
                          handler.playSongs(library.songs, shuffle: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      label: 'Favoritos',
                      icon: Icons.favorite_rounded,
                      iconColor: Palette.coral,
                      badge: favorites.isEmpty ? null : '${favorites.length}',
                      onTap: () => openFavorites(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      label: 'Recientes',
                      icon: Icons.schedule_rounded,
                      onTap: () => openRecentlyAdded(context),
                    ),
                  ),
                ],
              ),
            ),
            if (recents.isNotEmpty) ...[
              const SectionHeader('Escuchadas recientemente'),
              _Carousel(
                itemCount: recents.length,
                itemBuilder: (i) => CoverCard(
                  song: recents[i],
                  title: recents[i].title,
                  subtitle: recents[i].artist,
                  onTap: () => handler.playSongs(recents, startIndex: i),
                  onLongPress: () => showSongActions(context, ref, recents[i]),
                ),
              ),
            ],
            if (topSongs.isNotEmpty) ...[
              const SectionHeader('Tus más escuchadas'),
              _Carousel(
                itemCount: topSongs.length,
                itemBuilder: (i) => CoverCard(
                  song: topSongs[i],
                  title: topSongs[i].title,
                  subtitle: topSongs[i].artist,
                  onTap: () => handler.playSongs(topSongs, startIndex: i),
                  onLongPress: () => showSongActions(context, ref, topSongs[i]),
                ),
              ),
            ],
            const SectionHeader('Tu semana'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassSurface(
                radius: 28,
                padding: const EdgeInsets.all(20),
                child: WeekChart(week: week),
              ),
            ),
            if (albumsForYou.isNotEmpty) ...[
              const SectionHeader('Álbumes para hoy'),
              _Carousel(
                itemCount: albumsForYou.length,
                itemBuilder: (i) {
                  final album = albumsForYou[i];
                  return CoverCard(
                    song: album.songs.first,
                    title: album.title,
                    subtitle: album.artist,
                    onTap: () => openAlbum(context, album),
                  );
                },
              ),
            ],
            if (recentlyAdded.isNotEmpty) ...[
              SectionHeader(
                'Nuevas en tu teléfono',
                onTap: () => openRecentlyAdded(context),
              ),
              for (final (i, song) in recentlyAdded.indexed) ...[
                if (i > 0) const RowSeparator(),
                SongTile(
                  song: song,
                  onTap: () => handler.playSongs(recentlyAdded, startIndex: i),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  /// A different handful of albums each day, stable during the day.
  List<Album> _albumsOfTheDay(Library library) {
    final albums = library.albums.where((a) => a.songs.length > 1).toList();
    final now = DateTime.now();
    albums.shuffle(Random(now.year * 1000 + now.month * 50 + now.day));
    return albums.take(10).toList();
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    // Portada + dos líneas de texto; el texto crece con el tamaño de letra
    // del sistema, así que el alto no puede ser fijo.
    final textHeight = MediaQuery.textScalerOf(context).scale(38);
    return SizedBox(
      height: 156 + 8 + textHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => itemBuilder(i),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: GlassSurface(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: SizedBox(
          height: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor ?? accent, size: 24),
                  const Spacer(),
                  if (badge != null) Text(badge!, style: TextStyles.numbers),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onRescan});

  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassSurface(
        radius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No encontramos música', style: TextStyles.title),
            const SizedBox(height: 8),
            const Text(
              'Copia canciones a tu teléfono (por ejemplo a la carpeta Music) '
              'o revisa en Ajustes › Carpetas si alguna quedó excluida.',
              style: TextStyles.caption,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRescan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Volver a escanear'),
            ),
          ],
        ),
      ),
    );
  }
}
