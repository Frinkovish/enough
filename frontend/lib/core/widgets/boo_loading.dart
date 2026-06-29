import 'dart:async';

import 'package:flutter/material.dart';

import 'boo_avatar.dart';

/// Boo "thinking it over" — cycles through a few poses on a loop while
/// something we can't predict the duration of (an AI call) is in flight.
class BooLoading extends StatefulWidget {
  const BooLoading({super.key, this.size = 160, this.label});

  final double size;
  final String? label;

  static const _poses = [
    'assets/images/boo_confused.jpg',
    'assets/images/boo_counting_1.png',
    'assets/images/boo_counting_2.png',
    'assets/images/boo_counting_3.png',
  ];

  @override
  State<BooLoading> createState() => _BooLoadingState();
}

class _BooLoadingState extends State<BooLoading> {
  late final Timer _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() => _index = (_index + 1) % BooLoading._poses.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BooAvatar(size: widget.size, assetPath: BooLoading._poses[_index]),
        if (widget.label != null) ...[
          const SizedBox(height: 24),
          Text(
            widget.label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
