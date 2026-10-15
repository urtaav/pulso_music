import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/listening_stats.dart';

/// "Tu semana": minutes per day as glowing bars (L–D), today highlighted,
/// the busiest day in dot-matrix digits. Same idea as the stats widget.
class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.week, this.height = 120});

  final WeekSummary week;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final maxMinutes = week.minutes.fold(1, (a, b) => b > a ? b : a);
    final best = week.bestIndex;
    final favorite = week.favoriteWeekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatTotal(Duration(minutes: week.totalMinutes)),
              style: TextStyles.dots.copyWith(fontSize: 26),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('esta semana', style: TextStyles.caption),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: Semantics(
            label: [
              for (var i = 0; i < 7; i++)
                '${weekdayNames[i]} ${week.minutes[i]} minutos',
            ].join(', '),
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _Bar(
                        fraction: week.minutes[i] / maxMinutes,
                        highlight: i == best,
                        today: i == week.todayIndex,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == week.todayIndex
                          ? Glass.fillStrong
                          : Colors.transparent,
                    ),
                    child: Text(
                      weekdayInitials[i],
                      style: TextStyles.numbers.copyWith(
                        color: i == week.todayIndex
                            ? Palette.white
                            : Palette.grey,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (favorite != -1) ...[
          const SizedBox(height: 12),
          Text(
            'Tu día con más música: ${weekdayNames[favorite]}',
            style: TextStyles.caption,
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.highlight,
    required this.today,
    required this.color,
  });

  final double fraction;
  final bool highlight;
  final bool today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Un mínimo visible aunque no hayas escuchado nada ese día.
        final height = (constraints.maxHeight * fraction).clamp(
          4.0,
          constraints.maxHeight,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: height),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, h, _) => Container(
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: highlight
                    ? color
                    : (today
                          ? Palette.white.withValues(alpha: 0.7)
                          : Palette.white.withValues(alpha: 0.18)),
                boxShadow: highlight
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
