import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/library.dart';
import '../../data/song.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/artwork_palette.dart';
import '../common/glass.dart';
import '../common/pressable.dart';
import '../common/sections.dart';
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
    artistName: artist.name,
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
    emptyMessage: 'Agrega canciones desde su menú ••• › Agregar a una lista.',
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

/// Album, artist, folder, favorites or playlist, in the iOS 26 Music style:
/// full-bleed cover fading into a background tinted by that cover.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.playlistId,
    this.artistName,
    this.emptyMessage = 'No hay canciones aquí.',
  });

  final String title;
  final String? subtitle;
  final List<Song> Function(WidgetRef ref) songs;
  final String? playlistId;

  /// Set for artist pages, to show their featured album.
  final String? artistName;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = songs(ref);
    final cover = list.firstOrNull;
    final palette = cover == null
        ? ArtworkPalette.fallback
        : ref.watch(songPaletteProvider(cover.id)).value ??
              ArtworkPalette.fallback;
    final playlist = playlistId == null
        ? null
        : ref
              .watch(playlistsProvider)
              .where((p) => p.id == playlistId)
              .firstOrNull;
    final name = playlist?.name ?? title;
    final handler = ref.read(audioHandlerProvider);
    final total = list.fold(Duration.zero, (sum, s) => sum + s.duration);
    final featured = artistName == null
        ? null
        : _featuredAlbum(ref.watch(libraryValueProvider), artistName!);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          // El color de la portada baja por toda la pantalla y se apaga al final.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.background, Palette.background],
                  stops: const [0.45, 1],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  song: cover,
                  title: name,
                  subtitle: [
                    if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
                    songCount(list.length),
                    if (list.isNotEmpty) formatTotal(total),
                  ].join(' · '),
                  fadeTo: palette.background,
                  onShuffle: list.isEmpty
                      ? null
                      : () => handler.playSongs(list, shuffle: true),
                  onPlay: list.isEmpty ? null : () => handler.playSongs(list),
                  onQueue: list.isEmpty
                      ? null
                      : () {
                          handler.addAllToQueue(list);
                          showSnack(context, 'Agregadas a la cola');
                        },
                ),
              ),
              if (featured != null)
                SliverToBoxAdapter(child: _FeaturedAlbum(album: featured)),
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
              else ...[
                const SliverToBoxAdapter(child: SectionHeader('Canciones')),
                SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const RowSeparator(),
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
              ],
              SliverToBoxAdapter(child: SizedBox(height: bottomInset(context))),
            ],
          ),
          // Botones flotantes de vidrio sobre la portada.
          Positioned(
            top: top + 8,
            left: 16,
            child: GlassIconButton(
              tooltip: 'Atrás',
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 20,
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          if (playlist != null)
            Positioned(
              top: top + 8,
              right: 16,
              child: GlassIconButton(
                tooltip: 'Opciones de la lista',
                icon: Icons.more_horiz_rounded,
                onPressed: () => _playlistMenu(context, ref, playlist.id),
              ),
            ),
        ],
      ),
    );
  }

  /// The artist's album with the most songs in the library.
  Album? _featuredAlbum(Library library, String artist) {
    final albums = library.albums.where((a) => a.artist == artist).toList();
    if (albums.isEmpty) return null;
    albums.sort((a, b) => b.songs.length.compareTo(a.songs.length));
    return albums.first;
  }

  Future<void> _playlistMenu(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final controller = ref.read(playlistsProvider.notifier);
    final playlist = ref.read(playlistsProvider).firstWhere((p) => p.id == id);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Renombrar'),
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Palette.coral,
              ),
              title: const Text(
                'Eliminar lista',
                style: TextStyle(color: Palette.coral),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'rename') {
      final newName = await askName(
        context,
        title: 'Renombrar lista',
        initial: playlist.name,
      );
      if (newName != null) controller.rename(id, newName);
    } else if (await _confirmDelete(context, playlist.name)) {
      controller.delete(id);
      if (context.mounted) Navigator.pop(context);
    }
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.song,
    required this.title,
    required this.subtitle,
    required this.fadeTo,
    required this.onShuffle,
    required this.onPlay,
    required this.onQueue,
  });

  final Song? song;
  final String title;
  final String subtitle;
  final Color fadeTo;
  final VoidCallback? onShuffle;
  final VoidCallback? onPlay;
  final VoidCallback? onQueue;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: width + 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Artwork(song: song, size: width, radius: 0, highRes: true),
          ),
          // La portada se funde con el fondo, como en Apple Music.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  fadeTo.withValues(alpha: 0.6),
                  fadeTo,
                ],
                stops: const [0.45, 0.72, 0.92],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.display.copyWith(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.caption.copyWith(
                    color: Palette.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlassIconButton(
                      tooltip: 'Aleatorio',
                      icon: Icons.shuffle_rounded,
                      size: 64,
                      iconSize: 26,
                      onPressed: onShuffle,
                    ),
                    const SizedBox(width: 16),
                    GlassIconButton(
                      tooltip: 'Reproducir',
                      icon: Icons.play_arrow_rounded,
                      size: 64,
                      iconSize: 34,
                      onPressed: onPlay,
                    ),
                    const SizedBox(width: 16),
                    GlassIconButton(
                      tooltip: 'Agregar todo a la cola',
                      icon: Icons.queue_music_rounded,
                      size: 64,
                      iconSize: 26,
                      onPressed: onQueue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedAlbum extends StatelessWidget {
  const _FeaturedAlbum({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Pressable(
        onTap: () => openAlbum(context, album),
        semanticLabel: 'Álbum destacado: ${album.title}',
        child: GlassSurface(
          radius: 24,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Artwork(song: album.songs.first, size: 76, radius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ÁLBUM DESTACADO', style: TextStyles.overline),
                    const SizedBox(height: 4),
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      songCount(album.songs.length),
                      style: TextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Palette.grey),
            ],
          ),
        ),
      ),
    );
  }
}
