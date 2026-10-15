import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/library.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/glass.dart';
import '../common/sections.dart';
import '../common/song_tile.dart';
import 'collection_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Biblioteca', style: TextStyles.display),
            ),
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Canciones'),
                Tab(text: 'Álbumes'),
                Tab(text: 'Artistas'),
                Tab(text: 'Carpetas'),
                Tab(text: 'Listas'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SongsTab(),
                  _AlbumsTab(),
                  _ArtistsTab(),
                  _FoldersTab(),
                  _PlaylistsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongsTab extends ConsumerStatefulWidget {
  const _SongsTab();

  @override
  ConsumerState<_SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<_SongsTab> {
  SongSort _sort = SongSort.title;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryValueProvider);
    final songs = _sort.apply(library.songs);
    final handler = ref.read(audioHandlerProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(songCount(songs.length), style: TextStyles.numbers),
              ),
              PopupMenuButton<SongSort>(
                tooltip: 'Ordenar',
                initialValue: _sort,
                onSelected: (sort) => setState(() => _sort = sort),
                itemBuilder: (_) => [
                  for (final sort in SongSort.values)
                    PopupMenuItem(
                      value: sort,
                      child: Text('Por ${sort.label}'),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.swap_vert_rounded,
                        size: 18,
                        color: Palette.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(_sort.label, style: TextStyles.caption),
                    ],
                  ),
                ),
              ),
              GlassIconButton(
                tooltip: 'Aleatorio',
                icon: Icons.shuffle_rounded,
                size: 44,
                iconSize: 20,
                onPressed: songs.isEmpty
                    ? null
                    : () => handler.playSongs(songs, shuffle: true),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: bottomInset(context)),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const RowSeparator(),
            itemBuilder: (context, i) => SongTile(
              song: songs[i],
              onTap: () => handler.playSongs(songs, startIndex: i),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(libraryValueProvider).albums;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - 20 * 2 - 16) / 2;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset(context)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 16,
            childAspectRatio: cell / (cell + 50),
          ),
          itemCount: albums.length,
          itemBuilder: (context, i) {
            final album = albums[i];
            return CoverCard(
              song: album.songs.first,
              title: album.title,
              subtitle: album.artist,
              size: cell,
              onTap: () => openAlbum(context, album),
            );
          },
        );
      },
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(libraryValueProvider).artists;
    return ListView.separated(
      padding: EdgeInsets.only(top: 8, bottom: bottomInset(context)),
      itemCount: artists.length,
      separatorBuilder: (_, _) => const RowSeparator(),
      itemBuilder: (context, i) {
        final artist = artists[i];
        return ListTile(
          onTap: () => openArtist(context, artist),
          leading: Artwork(song: artist.songs.first, size: 48, radius: 24),
          title: Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${songCount(artist.songs.length)} · '
            '${artist.albumCount == 1 ? '1 álbum' : '${artist.albumCount} álbumes'}',
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Palette.grey,
          ),
        );
      },
    );
  }
}

class _FoldersTab extends ConsumerWidget {
  const _FoldersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref
        .watch(libraryValueProvider)
        .folders
        .where((f) => f.included)
        .toList();
    return ListView.separated(
      padding: EdgeInsets.only(top: 8, bottom: bottomInset(context)),
      itemCount: folders.length,
      separatorBuilder: (_, _) => const RowSeparator(indent: 72),
      itemBuilder: (context, i) {
        final folder = folders[i];
        return ListTile(
          onTap: () => openFolder(context, folder),
          leading: const CircleAvatar(
            backgroundColor: Glass.fill,
            child: Icon(Icons.folder_rounded, color: Palette.grey),
          ),
          title: Text(folder.name),
          subtitle: Text(
            folder.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text('${folder.songCount}', style: TextStyles.numbers),
        );
      },
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final favorites = ref.watch(favoritesProvider);
    final accent = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: EdgeInsets.only(top: 8, bottom: bottomInset(context)),
      children: [
        ListTile(
          onTap: () async {
            final name = await askName(context, title: 'Nueva lista');
            if (name != null) ref.read(playlistsProvider.notifier).create(name);
          },
          leading: CircleAvatar(
            backgroundColor: Glass.fill,
            child: Icon(Icons.add_rounded, color: accent),
          ),
          title: Text('Nueva lista', style: TextStyle(color: accent)),
        ),
        const RowSeparator(indent: 72),
        ListTile(
          onTap: () => openFavorites(context),
          leading: const CircleAvatar(
            backgroundColor: Glass.fill,
            child: Icon(Icons.favorite_rounded, color: Palette.coral),
          ),
          title: const Text('Favoritos'),
          subtitle: Text(songCount(favorites.length)),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Palette.grey,
          ),
        ),
        for (final playlist in playlists) ...[
          const RowSeparator(indent: 72),
          ListTile(
            onTap: () => openPlaylist(context, playlist.id),
            leading: const CircleAvatar(
              backgroundColor: Glass.fill,
              child: Icon(Icons.queue_music_rounded, color: Palette.grey),
            ),
            title: Text(playlist.name),
            subtitle: Text(songCount(playlist.songIds.length)),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Palette.grey,
            ),
          ),
        ],
      ],
    );
  }
}
