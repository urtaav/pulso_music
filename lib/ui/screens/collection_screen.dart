import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/library.dart';
import '../../data/song.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/song_tile.dart';

void openAlbum(BuildContext context, Album album) => _open(
  context,
  CollectionScreen(
    title: album.title,
    subtitle: album.artist,
    songs: (ref) =>
        ref
            .watch(libraryValueProvider)
            .albums
            .where((a) => a.id == album.id)
            .firstOrNull
            ?.songs ??
        const [],
  ),
);

void openArtist(BuildContext context, Artist artist) => _open(
  context,
  CollectionScreen(
    title: artist.name,
    subtitle: 'Artista',
    songs: (ref) =>
        ref
            .watch(libraryValueProvider)
            .artists
            .where((a) => a.name == artist.name)
            .firstOrNull
            ?.songs ??
        const [],
  ),
);

void openFolder(BuildContext context, FolderInfo folder) => _open(
  context,
  CollectionScreen(
    title: folder.name,
    subtitle: folder.path,
    songs: (ref) => ref.watch(libraryValueProvider).inFolder(folder.path),
  ),
);

void openFavorites(BuildContext context) => _open(
  context,
  CollectionScreen(
    title: 'Favoritos',
    subtitle: 'Tus canciones con corazón',
    emptyMessage: 'Toca el corazón en cualquier canción para guardarla aquí.',
    songs: (ref) =>
        ref.watch(libraryValueProvider).resolve(ref.watch(favoritesProvider)),
  ),
);

void openRecentlyAdded(BuildContext context) => _open(
  context,
  CollectionScreen(
    title: 'Agregadas recientemente',
    subtitle: 'Lo último en tu teléfono',
    songs: (ref) =>
        ref.watch(libraryValueProvider).recentlyAdded.take(100).toList(),
  ),
);

void openPlaylist(BuildContext context, String playlistId) => _open(
  context,
  CollectionScreen(
    title: '',
    playlistId: playlistId,
    emptyMessage: 'Agrega canciones desde su menú ⋮ › Agregar a una lista.',
    songs: (ref) {
      final playlist = ref
          .watch(playlistsProvider)
          .where((p) => p.id == playlistId)
          .firstOrNull;
      return playlist == null
          ? const []
          : ref.watch(libraryValueProvider).resolve(playlist.songIds);
    },
  ),
);

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    ),
  );
}

/// Album, artist, folder, favorites or playlist.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.playlistId,
    this.emptyMessage = 'No hay canciones aquí.',
  });

  final String title;
  final String? subtitle;
  final List<Song> Function(WidgetRef ref) songs;
  final String? playlistId;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = songs(ref);
    final playlist = playlistId == null
        ? null
        : ref
              .watch(playlistsProvider)
              .where((p) => p.id == playlistId)
              .firstOrNull;
    final name = playlist?.name ?? title;
    final handler = ref.read(audioHandlerProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final total = list.fold(Duration.zero, (sum, s) => sum + s.duration);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Palette.background,
            actions: [
              if (playlist != null)
                PopupMenuButton<String>(
                  tooltip: 'Opciones de la lista',
                  onSelected: (action) async {
                    final controller = ref.read(playlistsProvider.notifier);
                    if (action == 'rename') {
                      final newName = await askName(
                        context,
                        title: 'Renombrar lista',
                        initial: playlist.name,
                      );
                      if (newName != null) {
                        controller.rename(playlist.id, newName);
                      }
                    } else if (await _confirmDelete(context, playlist.name)) {
                      controller.delete(playlist.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar lista'),
                    ),
                  ],
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Artwork(
                    song: list.firstOrNull,
                    size: 168,
                    radius: 28,
                    highRes: true,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    style: TextStyles.display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
                      songCount(list.length),
                      if (list.isNotEmpty) formatTotal(total),
                    ].join(' · '),
                    style: TextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: list.isEmpty
                            ? null
                            : () => handler.playSongs(list),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Reproducir'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: list.isEmpty
                            ? null
                            : () => handler.playSongs(list, shuffle: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.5),
                          ),
                        ),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Aleatorio'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  emptyMessage,
                  style: TextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => SongTile(
                song: list[i],
                onTap: () => handler.playSongs(list, startIndex: i),
                onRemoveFromPlaylist: playlist == null
                    ? null
                    : () => ref
                          .read(playlistsProvider.notifier)
                          .removeSongAt(playlist.id, i),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar lista?'),
        content: Text('"$name" se eliminará. Las canciones no se borran.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.coral),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
