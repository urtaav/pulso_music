import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../state/providers.dart';
import '../common/artwork.dart';
import '../common/glass.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _QueueList(scrollController: scrollController),
    ),
  );
}

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(queueProvider);
    final handler = ref.read(audioHandlerProvider);
    final songs = handler.songs;
    final current = ref.watch(playbackStateProvider).value?.queueIndex ?? 0;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('A continuación', style: TextStyles.title),
              ),
              Text(songCount(songs.length), style: TextStyles.numbers),
            ],
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? const Center(
                  child: Text('La cola está vacía', style: TextStyles.caption),
                )
              : ReorderableListView.builder(
                  scrollController: scrollController,
                  buildDefaultDragHandles: false,
                  itemCount: songs.length,
                  onReorderItem: handler.moveQueueItem,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    final isCurrent = i == current;
                    // La clave combina posición e id: la misma canción puede
                    // estar dos veces en la cola.
                    return Dismissible(
                      key: ValueKey('${song.id}-$i'),
                      direction: isCurrent
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      background: Container(
                        color: Palette.coral.withValues(alpha: 0.25),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                      onDismissed: (_) => handler.removeQueueItemAt(i),
                      child: ListTile(
                        onTap: () => handler.skipToQueueItem(i),
                        leading: Artwork(song: song, size: 44, radius: 12),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.body.copyWith(
                            color: isCurrent ? accent : null,
                          ),
                        ),
                        subtitle: Text(
                          isCurrent ? 'Sonando ahora' : song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: Palette.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (songs.length > 1)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Arrastra para reordenar · desliza a la izquierda para quitar',
              style: TextStyles.caption,
            ),
          ),
      ],
    );
  }
}
