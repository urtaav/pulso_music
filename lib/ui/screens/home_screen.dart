import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/song.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/pressable.dart';
import '../common/song_tile.dart';
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
    final accent = Theme.of(context).colorScheme.primary;
    final recentlyAdded = library.recentlyAdded.take(8).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(greetingFor(DateTime.now()), style: TextStyles.display),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              libraryState.isLoading && library.songs.isEmpty
                  ? 'Buscando tu música…'
                  : '${library.songs.length} canciones · ${library.albums.length} álbumes',
              style: TextStyles.numbers.copyWith(
                color: Palette.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!libraryState.isLoading && library.songs.isEmpty)
            _EmptyLibrary(
              onRescan: () => ref.read(scannedSongsProvider.notifier).refresh(),
            )
          else ...[
            SizedBox(
              height: 112,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _QuickCard(
                    label: 'Aleatorio\ntodo',
                    icon: Icons.shuffle_rounded,
                    background: accent,
                    onTap: () =>
                        handler.playSongs(library.songs, shuffle: true),
                  ),
                  _QuickCard(
                    label: 'Favoritos',
                    icon: Icons.favorite_rounded,
                    background: Palette.coral,
                    trailing: '${favorites.length}',
                    onTap: () => openFavorites(context),
                  ),
                  _QuickCard(
                    label: 'Agregadas\nrecientemente',
                    icon: Icons.new_releases_outlined,
                    background: Palette.card,
                    onTap: () => openRecentlyAdded(context),
                  ),
                ],
              ),
            ),
            if (recents.isNotEmpty) ...[
              const _SectionTitle('Escuchadas recientemente'),
              SizedBox(
                height: 214,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: recents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _RecentCard(
                    song: recents[i],
                    color: [
                      accent,
                      Palette.coral,
                      Palette.white,
                      Palette.card,
                    ][i % 4],
                    onTap: () => handler.playSongs(recents, startIndex: i),
                  ),
                ),
              ),
            ],
            if (recentlyAdded.isNotEmpty) ...[
              const _SectionTitle('Nuevas en tu teléfono'),
              for (final (i, song) in recentlyAdded.indexed)
                SongTile(
                  song: song,
                  onTap: () => handler.playSongs(recentlyAdded, startIndex: i),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Text(text, style: TextStyles.title.copyWith(fontSize: 22)),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.on(background);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Pressable(
        onTap: onTap,
        semanticLabel: label.replaceAll('\n', ' '),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: ink),
                  const Spacer(),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: TextStyles.numbers.copyWith(color: ink),
                    ),
                ],
              ),
              // Se encoge en vez de desbordarse si una palabra no cabe.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  label,
                  style: TextStyles.body.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.song,
    required this.color,
    required this.onTap,
  });

  final Song song;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.on(color);
    return Pressable(
      onTap: onTap,
      semanticLabel: '${song.title}, ${song.artist}',
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(song: song, size: 132, radius: 20),
            const Spacer(),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.body.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.caption.copyWith(
                color: ink.withValues(alpha: 0.7),
              ),
            ),
          ],
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
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(28),
      ),
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
    );
  }
}
