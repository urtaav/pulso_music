import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Actions sent by the home screen widget buttons (WidgetActionReceiver.kt).
///
/// Recibe el contenedor de providers y no solo el handler: el ♡ del widget
/// cambia favoritos y la app debe enterarse sin reiniciar.
Future<void> runWidgetAction(ProviderContainer container, String action) async {
  final handler = container.read(audioHandlerProvider);
  switch (action) {
    case 'playPause':
      await handler.togglePlay();
    case 'next':
      await handler.skipToNext();
    case 'previous':
      await handler.skipToPrevious();
    case 'favorite':
      final song = handler.currentSong;
      if (song != null) {
        container.read(favoritesProvider.notifier).toggle(song.id);
      }
  }
}
