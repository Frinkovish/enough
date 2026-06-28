import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/craving_stats.dart';
import '../providers/stats_providers.dart';

/// Calm, no-guilt framing: a streak of 0 is shown as a plain number,
/// never as a loss or a broken streak — relapses are never the headline.
class StatsSummary extends ConsumerWidget {
  const StatsSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cravingStatsProvider);

    return stats.when(
      data: (data) => _StatsRow(stats: data),
      loading: () => const SizedBox(height: 64),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final CravingStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.totalDelayed == 0) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatTile(value: stats.totalDelayed, label: 'cravings delayed'),
        const SizedBox(width: 16),
        _StatTile(value: stats.currentStreak, label: 'in a row right now'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
