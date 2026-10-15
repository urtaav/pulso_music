import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/library.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/glass.dart';
import '../common/pressable.dart';
import '../common/sections.dart';
import '../common/song_tile.dart';
import 'collection_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryValueProvider);
    final query = _query.trim();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Buscar', style: TextStyles.display),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassSurface(
              radius: 24,
              child: TextField(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  hintText: 'Canciones, artistas, álbumes',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.cancel_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? _Browse(library: library)
                : _Results(library: library, query: query),
          ),
        ],
      ),
    );
  }
}

/// Before typing: the artists with the most songs, as round covers.
class _Browse extends StatelessWidget {
  const _Browse({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final artists = [...library.artists]
      ..sort((a, b) => b.songs.length.compareTo(a.songs.length));
    final top = artists.take(24).toList();
    if (top.isEmpty) {
      return const Center(
        child: Text('Escribe para buscar', style: TextStyles.caption),
      );
    }
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        const SliverToBoxAdapter(child: SectionHeader('Tus artistas')),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset(context)),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: top.length,
            itemBuilder: (context, i) {
              final artist = top[i];
              return Pressable(
                onTap: () => openArtist(context, artist),
                semanticLabel: artist.name,
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      Artwork(
                        song: artist.songs.first,
                        size: constraints.maxWidth,
                        radius: constraints.maxWidth / 2,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyles.caption.copyWith(
                          color: Palette.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.library, required this.query});

  final Library library;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = normalizeForSearch(query);
    final songs = searchSongs(library.songs, query);
    final artists = library.artists
        .where((a) => normalizeForSearch(a.name).contains(q))
        .take(8)
        .toList();
    final albums = library.albums
        .where((a) => normalizeForSearch(a.title).contains(q))
        .take(10)
        .toList();
    final handler = ref.read(audioHandlerProvider);

    if (songs.isEmpty && artists.isEmpty && albums.isEmpty) {
      return const Center(
        child: Text('Sin resultados', style: TextStyles.caption),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottomInset(context)),
      children: [
        if (artists.isNotEmpty) ...[
          const SectionHeader('Artistas'),
          for (final artist in artists)
            ListTile(
              onTap: () => openArtist(context, artist),
              leading: Artwork(song: artist.songs.first, size: 48, radius: 24),
              title: Text(artist.name),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Palette.grey,
              ),
            ),
        ],
        if (albums.isNotEmpty) ...[
          const SectionHeader('Álbumes'),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: albums.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => CoverCard(
                song: albums[i].songs.first,
                title: albums[i].title,
                subtitle: albums[i].artist,
                size: 140,
                onTap: () => openAlbum(context, albums[i]),
              ),
            ),
          ),
        ],
        if (songs.isNotEmpty) ...[
          const SectionHeader('Canciones'),
          for (final (i, song) in songs.take(60).indexed) ...[
            if (i > 0) const RowSeparator(),
            SongTile(
              song: song,
              onTap: () => handler.playSongs(songs, startIndex: i),
            ),
          ],
        ],
      ],
    );
  }
}
