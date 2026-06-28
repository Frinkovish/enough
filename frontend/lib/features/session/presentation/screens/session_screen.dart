import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../providers/active_session_controller.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/task_suggestion_card.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ActiveSessionState?>(activeSessionControllerProvider, (previous, next) {
      if (next != null && next.isFinished) {
        context.go(AppRoutes.sessionOutcome);
      }
    });

    final activeSession = ref.watch(activeSessionControllerProvider);

    if (activeSession == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const SizedBox.shrink();
    }

    final remaining = Duration(seconds: activeSession.remainingSeconds);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Text(
                  'Take this time for yourself',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                CountdownRing(remaining: remaining, progress: activeSession.progress),
                const SizedBox(height: 32),
                TaskSuggestionCard(
                  task: activeSession.session.suggestedTask,
                  isRefreshing: activeSession.isRefreshingSuggestion,
                  onRefresh: () => ref.read(activeSessionControllerProvider.notifier).refreshSuggestion(),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(activeSessionControllerProvider.notifier).endEarly(),
                  child: const Text("I'm ready to decide now"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
