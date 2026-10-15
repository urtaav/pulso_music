import 'package:flutter/material.dart';

/// Round play/pause button whose icon morphs between both states.
class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onPressed,
    this.size = 72,
    this.background = Colors.white,
    this.foreground = Colors.black,
  });

  final bool playing;
  final VoidCallback onPressed;
  final double size;
  final Color background;
  final Color foreground;

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.playing ? 1 : 0,
  );

  @override
  void didUpdateWidget(PlayPauseButton old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) {
      widget.playing ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.playing ? 'Pausar' : 'Reproducir',
      child: Material(
        color: widget.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: widget.size,
            child: Center(
              child: AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeInOutCubic,
                ),
                size: widget.size * 0.45,
                color: widget.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
