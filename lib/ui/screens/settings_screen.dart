import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../data/settings.dart';
import '../../state/providers.dart';
import '../common/sections.dart';
import '../player/sleep_timer_sheet.dart';
import '../visualizer/edge_visualizer.dart';
import 'folders_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final scan = ref.watch(scannedSongsProvider);
    final library = ref.watch(libraryValueProvider);
    final micGranted = ref.watch(micPermissionProvider).value ?? false;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomInset(context)),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Ajustes', style: TextStyles.display),
          ),

          const _Header('Biblioteca'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Volver a escanear'),
            subtitle: Text(
              scan.isLoading
                  ? 'Escaneando…'
                  : '${library.songs.length} canciones en '
                        '${library.folders.where((f) => f.included).length} carpetas',
            ),
            trailing: scan.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: scan.isLoading
                ? null
                : () => ref.read(scannedSongsProvider.notifier).refresh(),
          ),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('Carpetas'),
            subtitle: const Text('Elige qué carpetas forman tu biblioteca'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FoldersScreen()),
            ),
          ),
          _SliderTile(
            title: 'Duración mínima',
            caption: settings.minDurationSeconds == 0
                ? 'Incluir todos los audios'
                : 'Ignorar audios de menos de ${settings.minDurationSeconds} s',
            value: settings.minDurationSeconds.toDouble(),
            min: 0,
            max: 120,
            divisions: 24,
            onChanged: (v) => controller.update(
              (s) => s.copyWith(minDurationSeconds: v.round()),
            ),
          ),

          const _Header('Apariencia'),
          _ColorRow(
            label: 'Color de acento',
            colors: Palette.accents,
            selected: settings.accent,
            onSelected: (c) => controller.update((s) => s.copyWith(accent: c)),
          ),

          const _Header('Animación de bordes'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: VisualizerPreview(),
          ),
          _ChipGroup<VisualizerPosition>(
            label: 'Posición',
            values: VisualizerPosition.values,
            selected: settings.visualizerPosition,
            labelOf: (p) => p.label,
            onSelected: (p) =>
                controller.update((s) => s.copyWith(visualizerPosition: p)),
          ),
          if (settings.visualizerEnabled) ...[
            _ChipGroup<VisualizerStyle>(
              label: 'Estilo',
              values: VisualizerStyle.values,
              selected: settings.visualizerStyle,
              labelOf: (s) => s.label,
              onSelected: (style) =>
                  controller.update((s) => s.copyWith(visualizerStyle: style)),
            ),
            _SliderTile(
              title: 'Intensidad',
              caption: '${(settings.visualizerIntensity * 100).round()}%',
              value: settings.visualizerIntensity,
              min: 0.2,
              max: 1,
              divisions: 8,
              onChanged: (v) =>
                  controller.update((s) => s.copyWith(visualizerIntensity: v)),
            ),
            ListTile(
              leading: Icon(
                micGranted
                    ? Icons.check_circle_rounded
                    : Icons.mic_none_rounded,
                color: micGranted
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('Reaccionar al audio real'),
              subtitle: Text(
                micGranted
                    ? 'Activo: sigue lo que está sonando'
                    : 'Ahora es simulada. Toca para permitir',
              ),
              onTap: micGranted
                  ? openAppSettings
                  : () => askVisualizerPermission(context, ref),
            ),
          ],

          const _Header('Reproducción'),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Temporizador de apagado'),
            subtitle: SleepTimerLabel(style: TextStyles.caption),
            onTap: () => showSleepTimerSheet(context),
          ),

          const _Header('Widget de inicio'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _WidgetPreview(settings: settings),
          ),
          _ColorRow(
            label: 'Fondo',
            colors: Palette.widgetBackgrounds,
            selected: settings.widgetBackground,
            onSelected: (c) =>
                controller.update((s) => s.copyWith(widgetBackground: c)),
          ),
          _ColorRow(
            label: 'Botón',
            colors: Palette.accents,
            selected: settings.widgetAccent,
            onSelected: (c) =>
                controller.update((s) => s.copyWith(widgetAccent: c)),
          ),
          _SliderTile(
            title: 'Opacidad del fondo',
            caption: '${(settings.widgetOpacity * 100).round()}%',
            value: settings.widgetOpacity,
            min: 0.3,
            max: 1,
            divisions: 7,
            onChanged: (v) =>
                controller.update((s) => s.copyWith(widgetOpacity: v)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Para agregarlo: mantén presionada la pantalla de inicio › Widgets › '
              'pulso. Arrastra sus bordes para cambiar el tamaño: tiene diseño '
              'pequeño, mediano y grande.',
              style: TextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
      child: Text(
        text,
        style: TextStyles.title.copyWith(
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Wrapping row of choice chips; better than a segmented button when the
/// options don't fit in one line.
class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyles.body),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(labelOf(value)),
                  selected: value == selected,
                  showCheckmark: false,
                  onSelected: (_) => onSelected(value),
                  backgroundColor: Glass.fill,
                  selectedColor: accent,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value == selected
                        ? Palette.on(accent)
                        : Palette.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.caption,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String caption;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyles.body),
          Text(caption, style: TextStyles.caption),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<Color> colors;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyles.body),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (i, color) in colors.indexed)
                Semantics(
                  button: true,
                  selected: color.toARGB32() == selected,
                  label: '$label, opción ${i + 1}',
                  child: GestureDetector(
                    onTap: () => onSelected(color.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.toARGB32() == selected
                              ? Palette.white
                              : Palette.cardHigh,
                          width: color.toARGB32() == selected ? 3 : 1,
                        ),
                      ),
                      child: color.toARGB32() == selected
                          ? Icon(Icons.check_rounded, color: Palette.on(color))
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Flutter replica of the medium home widget, to preview colors live.
class _WidgetPreview extends ConsumerWidget {
  const _WidgetPreview({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    final background = Color(settings.widgetBackground)
        .withValues(alpha: settings.widgetOpacity);
    final accent = Color(settings.widgetAccent);
    final ink = Palette.on(Color(settings.widgetBackground));
    return Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Palette.cardHigh),
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.music_note_rounded, color: Palette.on(accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song?.title ?? 'pulso',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  song?.artist ?? 'toca para empezar',
                  maxLines: 1,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.skip_previous_rounded, color: ink),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: accent,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Palette.on(accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.skip_next_rounded, color: ink),
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
