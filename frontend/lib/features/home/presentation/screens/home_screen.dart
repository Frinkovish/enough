import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/boo_avatar.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/presentation/widgets/goals_section.dart';
import '../../../session/domain/location_context.dart';
import '../../../session/presentation/providers/session_providers.dart';
import '../../../session/presentation/widgets/craving_intake_sheet.dart';
import '../../../stats/presentation/widgets/stats_summary.dart';
import '../widgets/craving_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final locationContext = ref.watch(locationContextProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enough'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin',
              onPressed: () => context.push(AppRoutes.admin),
            ),
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
                  SegmentedButton<LocationContext>(
                    segments: const [
                      ButtonSegment(
                        value: LocationContext.home,
                        icon: Icon(Icons.home_outlined),
                        label: Text('Home'),
                      ),
                      ButtonSegment(
                        value: LocationContext.work,
                        icon: Icon(Icons.work_outline),
                        label: Text('Work'),
                      ),
                    ],
                    selected: {locationContext},
                    onSelectionChanged: (selection) => ref
                        .read(locationContextProvider.notifier)
                        .state = selection.first,
                  ),
                  const SizedBox(height: 8),
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
                  const BooAvatar(size: 100, assetPath: 'assets/images/boo_welcome.png'),
                  const SizedBox(height: 16),
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
                    onPressed: () => showCravingIntakeSheet(context),
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
