import 'package:flutter/material.dart';

/// Boo, the app's mascot — a gently bobbing circular avatar cropped from
/// the source artwork. Reusable anywhere we want Boo present on screen.
class BooAvatar extends StatefulWidget {
  const BooAvatar({super.key, this.size = 140});

  final double size;

  @override
  State<BooAvatar> createState() => _BooAvatarState();
}

class _BooAvatarState extends State<BooAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bob;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _bob = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(offset: Offset(0, _bob.value), child: child),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset('assets/images/boo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
