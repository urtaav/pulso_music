import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';

/// Every folder where audio was found, with a switch to include/exclude it.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(libraryValueProvider).folders;
    final overrides = ref.read(folderOverridesProvider.notifier);
    final included = folders.where((f) => f.included).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Carpetas')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '$included de ${folders.length} carpetas incluidas. WhatsApp, '
              'notas de voz, grabaciones y tonos del sistema vienen excluidos; '
              'actívalos si quieres verlos.',
              style: TextStyles.caption,
            ),
          ),
          for (final folder in folders)
            SwitchListTile(
              value: folder.included,
              onChanged: (value) => overrides.set(folder.path, value),
              title: Text(folder.name),
              subtitle: Text(
                [
                  '${folder.songCount} archivos',
                  if (folder.excludedByDefault) 'excluida por defecto',
                  folder.path,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
