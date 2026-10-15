import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/providers.dart';
import '../common/glass.dart';
import '../player/mini_player.dart';

class ShellTab {
  const ShellTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Tabs shown in the glass pill; search lives in its own circle.
const shellTabs = [
  ShellTab('Inicio', Icons.home_outlined, Icons.home_rounded),
  ShellTab(
    'Biblioteca',
    Icons.library_music_outlined,
    Icons.library_music_rounded,
  ),
  ShellTab('Ajustes', Icons.tune_outlined, Icons.tune_rounded),
];
const searchTabIndex = 3;

const _barHeight = 62.0;
const _gap = 10.0;

/// Room the floating chrome takes at its tallest, so content can scroll
/// fully above it.
double bottomChromeHeight({required bool hasSong}) =>
    _barHeight + (hasSong ? _barHeight + _gap : 0) + _gap * 2;

/// Floating glass bottom bar, as in iOS 26 Music: mini player capsule on top
/// of a tab pill and a search circle. While scrolling down it collapses into
/// a single row (tab circle · mini player · search) to free the screen.
class BottomChrome extends ConsumerWidget {
  const BottomChrome({
    super.key,
    required this.tab,
    required this.onTab,
    required this.collapsed,
    required this.onExpand,
  });

  final int tab;
  final ValueChanged<int> onTab;
  final bool collapsed;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSong = ref.watch(currentSongProvider) != null;
    final compact = collapsed && hasSong;
    final search = _SearchCircle(
      selected: tab == searchTabIndex,
      onTap: () => onTab(searchTabIndex),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: compact
            ? Row(
                key: const ValueKey('compact'),
                children: [
                  _CurrentTabCircle(
                    tab: tab == searchTabIndex ? null : shellTabs[tab],
                    onTap: onExpand,
                  ),
                  const SizedBox(width: _gap),
                  const Expanded(child: MiniPlayer(height: _barHeight)),
                  const SizedBox(width: _gap),
                  search,
                ],
              )
            : Column(
                key: const ValueKey('full'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSong) ...[
                    const MiniPlayer(height: _barHeight),
                    const SizedBox(height: _gap),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _TabPill(selected: tab, onTab: onTab),
                      ),
                      const SizedBox(width: _gap),
                      search,
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.selected, required this.onTab});

  final int selected;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GlassSurface(
      radius: _barHeight / 2,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: _barHeight - 8,
        child: Row(
          children: [
            for (final (i, tab) in shellTabs.indexed)
              Expanded(
                child: Semantics(
                  selected: i == selected,
                  button: true,
                  label: tab.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTab(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: i == selected
                            ? Glass.fillStrong
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(_barHeight / 2),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == selected ? tab.selectedIcon : tab.icon,
                              size: 24,
                              color: i == selected ? accent : Palette.white,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: i == selected ? accent : Palette.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchCircle extends StatelessWidget {
  const _SearchCircle({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      tooltip: 'Buscar',
      icon: Icons.search_rounded,
      size: _barHeight,
      iconSize: 26,
      iconColor: selected ? Theme.of(context).colorScheme.primary : null,
      onPressed: onTap,
    );
  }
}

class _CurrentTabCircle extends StatelessWidget {
  const _CurrentTabCircle({required this.tab, required this.onTap});

  final ShellTab? tab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      tooltip: 'Mostrar pestañas',
      icon: tab?.selectedIcon ?? Icons.search_rounded,
      size: _barHeight,
      iconSize: 26,
      onPressed: onTap,
    );
  }
}
