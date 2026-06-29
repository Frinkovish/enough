import 'package:flutter/material.dart';

/// Full-screen backdrop that slowly drifts between two soft gradients on a
/// loop. There's no vector animation asset for Boo (just a static PNG), so
/// a real Lottie loop isn't possible yet — this gives the same "alive"
/// feel with zero extra assets or dependencies.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key});

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t, -1 + t),
              end: Alignment(1 - t, 1 - t),
              colors: [
                Color.lerp(scheme.surface, scheme.primaryContainer, t)!,
                Color.lerp(scheme.secondaryContainer, scheme.tertiaryContainer, t)!,
              ],
            ),
          ),
        );
      },
    );
  }
}
