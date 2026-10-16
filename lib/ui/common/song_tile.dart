import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/song.dart';
import '../../state/providers.dart';
import '../screens/collection_screen.dart';
import 'artwork.dart';
import 'glass.dart';

class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onRemoveFromPlaylist,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentSongProvider)?.id == song.id;
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      onTap: onTap,
      onLongPress: () => showSongActions(
        context,
        ref,
        song,
        onRemoveFromPlaylist: onRemoveFromPlaylist,
      ),
      leading: Artwork(song: song, size: 48, radius: 10),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyles.body.copyWith(color: isCurrent ? accent : null),
      ),
      subtitle: Text(
        '${song.artist} · ${formatDuration(song.duration)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeartButton(songId: song.id),
          IconButton(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_horiz_rounded, color: Palette.grey),
            onPressed: () => showSongActions(
              context,
              ref,
              song,
              onRemoveFromPlaylist: onRemoveFromPlaylist,
            ),
          ),
        ],
      ),
    );
  }
}

class HeartButton extends ConsumerWidget {
  const HeartButton({super.key, required this.songId, this.size = 22});

  final int songId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(
      favoritesProvider.select((f) => f.contains(songId)),
    );
    return IconButton(
      tooltip: liked ? 'Quitar de favoritos' : 'Agregar a favoritos',
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(songId),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(liked),
          size: size,
          color: liked ? Palette.coral : Palette.grey,
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showSongActions(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  VoidCallback? onRemoveFromPlaylist,
}) async {
  final handler = ref.read(audioHandlerProvider);
  final library = ref.read(libraryValueProvider);
  await showGlassSheet<void>(
    context: context,
    builder: (sheetContext) {
      void close() => Navigator.pop(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(song: song, size: 48, radius: 10),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(song.artist),
            ),
            const Divider(color: Palette.separator),
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Reproducir a continuación'),
              onTap: () {
                close();
                handler.playNext(song);
                showSnack(context, 'Sonará a continuación');
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Agregar a la cola'),
              onTap: () {
                close();
                handler.addToQueue(song);
                showSnack(context, 'Agregada a la cola');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Agregar a una lista'),
              onTap: () {
                close();
                showAddToPlaylist(context, ref, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.album_rounded),
              title: const Text('Ir al álbum'),
              onTap: () {
                close();
                final album = library.albums
                    .where((a) => a.id == song.albumId)
                    .firstOrNull;
                if (album != null) openAlbum(context, album);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Ir al artista'),
              onTap: () {
                close();
                final artist = library.artists
                    .where((a) => a.name == song.artist)
                    .firstOrNull;
                if (artist != null) openArtist(context, artist);
              },
            ),
            if (onRemoveFromPlaylist != null)
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Palette.coral,
                ),
                title: const Text(
                  'Quitar de esta lista',
                  style: TextStyle(color: Palette.coral),
                ),
                onTap: () {
                  close();
                  onRemoveFromPlaylist();
                },
              ),
          ],
        ),
      );
    },
  );
}

Future<void> showAddToPlaylist(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final playlists = ref.read(playlistsProvider);
  final controller = ref.read(playlistsProvider.notifier);
  final choice = await showGlassSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Agregar a', style: TextStyles.title)),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Nueva lista'),
            onTap: () => Navigator.pop(sheetContext, ''),
          ),
          for (final p in playlists)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(p.name),
              subtitle: Text(songCount(p.songIds.length)),
              onTap: () => Navigator.pop(sheetContext, p.id),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  var playlistId = choice;
  if (choice.isEmpty) {
    final name = await askName(context, title: 'Nueva lista');
    if (name == null || !context.mounted) return;
    playlistId = controller.create(name).id;
  }
  final added = controller.addSong(playlistId, song.id);
  if (context.mounted) {
    showSnack(context, added ? 'Agregada a la lista' : 'Ya estaba en la lista');
  }
}

Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nombre'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
