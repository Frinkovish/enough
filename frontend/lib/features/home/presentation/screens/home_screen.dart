import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/presentation/widgets/goals_section.dart';
import '../../../session/presentation/providers/active_session_controller.dart';
import '../../../session/presentation/widgets/craving_trigger_sheet.dart';
import '../../../stats/presentation/widgets/stats_summary.dart';
import '../widgets/craving_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enough'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  const StatsSummary(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.insights),
                      child: const Text('View your patterns'),
                    ),
                  ),
                  const GoalsSection(),
                  const SizedBox(height: 32),
                  Text(
                    'Feeling a craving?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Give yourself 20 minutes. No pressure either way.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),
                  CravingButton(
                    onPressed: () async {
                      final trigger = await showCravingTriggerSheet(context);
                      if (trigger == null || !context.mounted) return;
                      await ref.read(activeSessionControllerProvider.notifier).startSession(trigger);
                      if (context.mounted) context.go(AppRoutes.session);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
