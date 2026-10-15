import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/song.dart';
import 'artwork.dart';
import 'pressable.dart';

/// Bottom space so the end of a list clears the floating glass bar.
double bottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 16;

/// "Escuchadas recientemente ›" — tappable when [onTap] is set.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onTap, this.trailing});

  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 12),
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyles.title.copyWith(fontSize: 22),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Palette.grey,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Square cover with title and subtitle underneath, for carousels and grids.
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.song,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.size = 156,
    this.onLongPress,
  });

  final Song? song;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: '$title, $subtitle',
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(song: song, size: size, radius: 14),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.body.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hairline between rows, indented past the artwork like iOS lists.
class RowSeparator extends StatelessWidget {
  const RowSeparator({super.key, this.indent = 80});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 0.5,
    indent: indent,
    endIndent: 16,
    color: Palette.separator,
  );
}
