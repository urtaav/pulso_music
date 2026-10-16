import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Frosted glass panel: blurs whatever is behind it.
///
/// BackdropFilter is expensive, so it's only used for floating chrome
/// (bars, round buttons, cards over images), not for every list row.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.circle = false,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.strong = false,
  });

  final Widget child;
  final double radius;
  final bool circle;
  final EdgeInsetsGeometry padding;

  /// Optional color mixed into the fill (e.g. from the artwork).
  final Color? tint;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final fill = strong ? Glass.fillStrong : Glass.fill;

    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      // grouped: dentro de un BackdropGroup comparte la captura del fondo con
      // las demás tarjetas; sin grupo se comporta como un BackdropFilter normal.
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: Glass.blur, sigmaY: Glass.blur),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape.copyWith(
              side: const BorderSide(color: Glass.border, width: 0.8),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(Glass.highlight, fill),
                tint == null
                    ? fill
                    : Color.alphaBlend(tint!.withValues(alpha: 0.18), fill),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Round glass button (back, more, play…), 48 dp hit area minimum.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.iconSize = 22,
    this.filled = false,
    this.iconColor,
  });

  final Color? iconColor;
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final double iconSize;

  /// Solid white instead of glass, for the main action.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ?? (filled ? Colors.black : Palette.white),
          ),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: filled
          ? DecoratedBox(
              decoration: const BoxDecoration(
                color: Palette.white,
                shape: BoxShape.circle,
              ),
              child: button,
            )
          : GlassSurface(circle: true, child: button),
    );
  }
}

/// Bottom sheet made of frosted glass instead of a solid panel.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    builder: (sheetContext) => _GlassSheet(child: builder(sheetContext)),
  );
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0x991C1C1E),
            border: Border(top: BorderSide(color: Glass.border, width: 0.8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Palette.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
