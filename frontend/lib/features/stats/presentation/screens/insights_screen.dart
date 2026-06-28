import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/responsive_center.dart';
import '../../../session/domain/craving_trigger.dart';
import '../../domain/craving_insights.dart';
import '../providers/stats_providers.dart';

const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', // 1-indexed
];

String _shortDate(DateTime date) => '${_monthAbbreviations[date.month - 1]} ${date.day}';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(cravingInsightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your patterns')),
      body: SafeArea(
        child: insights.when(
          data: (data) => _InsightsBody(insights: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text("Couldn't load your patterns right now. Please try again later."),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.insights});

  final CravingInsights insights;

  @override
  Widget build(BuildContext context) {
    if (insights.totalSessions == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Once you start delaying a few cravings, patterns will start showing up here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: ResponsiveCenter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryGrid(insights: insights),
              const SizedBox(height: 32),
              Text('Last 8 weeks', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _WeeklyTrendChart(weeklyTrend: insights.weeklyTrend),
              const SizedBox(height: 32),
              if (insights.byTrigger.isNotEmpty) ...[
                Text('By what triggered it', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _TriggerBreakdown(byTrigger: insights.byTrigger),
                const SizedBox(height: 32),
              ],
              if (insights.byDayPart.isNotEmpty) ...[
                Text('When cravings happen', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _DayPartBreakdown(byDayPart: insights.byDayPart),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.insights});

  final CravingInsights insights;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryTile(value: insights.bestStreak, label: 'best streak'),
        const SizedBox(width: 12),
        _SummaryTile(value: insights.totalDelayed, label: 'delayed, ever'),
        const SizedBox(width: 12),
        _SummaryTile(value: insights.goalsCompleted, label: 'goals completed'),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.value, required this.label});

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
              Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  const _WeeklyTrendChart({required this.weeklyTrend});

  final List<WeeklyBucket> weeklyTrend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxCount = weeklyTrend
        .map((week) => week.delayed + week.smoked)
        .fold<int>(0, (max, value) => value > max ? value : max);
    final maxY = maxCount == 0 ? 1.0 : (maxCount + 1).toDouble();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= weeklyTrend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _shortDate(weeklyTrend[index].weekStart),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < weeklyTrend.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (weeklyTrend[i].delayed + weeklyTrend[i].smoked).toDouble(),
                    rodStackItems: [
                      BarChartRodStackItem(0, weeklyTrend[i].delayed.toDouble(), colorScheme.primary),
                      BarChartRodStackItem(
                        weeklyTrend[i].delayed.toDouble(),
                        (weeklyTrend[i].delayed + weeklyTrend[i].smoked).toDouble(),
                        colorScheme.outlineVariant,
                      ),
                    ],
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TriggerBreakdown extends StatelessWidget {
  const _TriggerBreakdown({required this.byTrigger});

  final Map<CravingTrigger, TriggerStats> byTrigger;

  @override
  Widget build(BuildContext context) {
    final entries = byTrigger.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));
    final maxTotal = entries.first.value.total;

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BreakdownRow(
              label: entry.key.label,
              delayed: entry.value.delayed,
              smoked: entry.value.smoked,
              maxTotal: maxTotal,
            ),
          ),
      ],
    );
  }
}

class _DayPartBreakdown extends StatelessWidget {
  const _DayPartBreakdown({required this.byDayPart});

  final Map<DayPart, int> byDayPart;

  @override
  Widget build(BuildContext context) {
    final maxTotal = byDayPart.values.fold<int>(0, (max, value) => value > max ? value : max);

    return Column(
      children: [
        for (final part in DayPart.values)
          if (byDayPart.containsKey(part))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BreakdownRow(
                label: part.label,
                delayed: byDayPart[part]!,
                smoked: 0,
                maxTotal: maxTotal,
              ),
            ),
      ],
    );
  }
}

/// A simple proportional bar: calm, no chart-junk, just relative scale.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.delayed,
    required this.smoked,
    required this.maxTotal,
  });

  final String label;
  final int delayed;
  final int smoked;
  final int maxTotal;

  @override
  Widget build(BuildContext context) {
    final total = delayed + smoked;
    final fraction = maxTotal == 0 ? 0.0 : total / maxTotal;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text('$total', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
