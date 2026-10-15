import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SafeArea(child: _SleepTimerOptions()),
  );
}

class _SleepTimerOptions extends ConsumerWidget {
  const _SleepTimerOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final state = ref.watch(sleepTimerProvider).value;

    void choose(VoidCallback action, String message) {
      action();
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Temporizador', style: TextStyles.title),
          subtitle: state?.isActive == true
              ? SleepTimerLabel(style: TextStyles.numbers)
              : const Text('Pausa la música automáticamente'),
        ),
        for (final minutes in const [15, 30, 60])
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text('$minutes minutos'),
            onTap: () => choose(
              () => handler.setSleepTimer(Duration(minutes: minutes)),
              'Se pausará en $minutes minutos',
            ),
          ),
        ListTile(
          leading: const Icon(Icons.music_off_outlined),
          title: const Text('Al terminar la canción'),
          onTap: () => choose(
            handler.sleepAtEndOfTrack,
            'Se pausará al terminar esta canción',
          ),
        ),
        if (state?.isActive == true)
          ListTile(
            leading: const Icon(Icons.close_rounded, color: Palette.coral),
            title: const Text(
              'Cancelar temporizador',
              style: TextStyle(color: Palette.coral),
            ),
            onTap: () =>
                choose(handler.cancelSleepTimer, 'Temporizador cancelado'),
          ),
      ],
    );
  }
}

/// "se apaga en 12:30" / "al terminar la canción", ticking every second.
class SleepTimerLabel extends ConsumerWidget {
  const SleepTimerLabel({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepTimerProvider).value;
    if (state == null || !state.isActive) return const SizedBox.shrink();
    if (state.endOfTrack) {
      return Text('Se pausa al terminar la canción', style: style);
    }
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final left = state.endsAt!.difference(DateTime.now());
        final minutes = left.inMinutes;
        final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          left.isNegative ? '' : 'Se pausa en $minutes:$seconds',
          style: style,
        );
      },
    );
  }
}
