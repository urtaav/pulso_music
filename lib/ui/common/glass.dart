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
      child: BackdropFilter(
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
