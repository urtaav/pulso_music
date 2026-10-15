import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/library.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/pressable.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
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
                        Icons.sort_rounded,
                        size: 18,
                        color: Palette.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(_sort.label, style: TextStyles.caption),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Aleatorio',
                icon: const Icon(Icons.shuffle_rounded),
                onPressed: songs.isEmpty
                    ? null
                    : () => handler.playSongs(songs, shuffle: true),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
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
        final cell = (constraints.maxWidth - 16 * 3) / 2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: cell / (cell + 52),
          ),
          itemCount: albums.length,
          itemBuilder: (context, i) {
            final album = albums[i];
            return Pressable(
              onTap: () => openAlbum(context, album),
              semanticLabel: '${album.title}, ${album.artist}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Artwork(song: album.songs.first, size: cell, radius: 24),
                  const SizedBox(height: 8),
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.caption,
                  ),
                ],
              ),
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
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: artists.length,
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
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: folders.length,
      itemBuilder: (context, i) {
        final folder = folders[i];
        return ListTile(
          onTap: () => openFolder(context, folder),
          leading: const CircleAvatar(
            backgroundColor: Palette.card,
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
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        ListTile(
          onTap: () async {
            final name = await askName(context, title: 'Nueva lista');
            if (name != null) ref.read(playlistsProvider.notifier).create(name);
          },
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.add_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          title: const Text('Nueva lista'),
        ),
        ListTile(
          onTap: () => openFavorites(context),
          leading: const CircleAvatar(
            backgroundColor: Palette.coral,
            child: Icon(Icons.favorite_rounded, color: Colors.black),
          ),
          title: const Text('Favoritos'),
          subtitle: Text(songCount(favorites.length)),
        ),
        for (final playlist in playlists)
          ListTile(
            onTap: () => openPlaylist(context, playlist.id),
            leading: const CircleAvatar(
              backgroundColor: Palette.card,
              child: Icon(Icons.queue_music_rounded, color: Palette.grey),
            ),
            title: Text(playlist.name),
            subtitle: Text(songCount(playlist.songIds.length)),
          ),
      ],
    );
  }
}
