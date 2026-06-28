import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../domain/craving_session.dart';
import '../../domain/task_suggestion.dart';
import '../providers/active_session_controller.dart';

class SessionOutcomeScreen extends ConsumerStatefulWidget {
  const SessionOutcomeScreen({super.key});

  @override
  ConsumerState<SessionOutcomeScreen> createState() => _SessionOutcomeScreenState();
}

class _SessionOutcomeScreenState extends ConsumerState<SessionOutcomeScreen> {
  SessionOutcome? _outcome;

  void _chooseOutcome(SessionOutcome outcome) {
    setState(() => _outcome = outcome);
  }

  Future<void> _chooseTaskCompletion(bool completed) async {
    final outcome = _outcome;
    if (outcome == null) return;
    try {
      await ref
          .read(activeSessionControllerProvider.notifier)
          .recordOutcome(outcome, taskCompleted: completed);
    } catch (error, stackTrace) {
      // Logged so the real cause (e.g. an RLS permission error from
      // Supabase) is visible during development instead of only showing
      // the user a generic message.
      debugPrint('Failed to save session outcome: $error\n$stackTrace');
      // Don't trap the user here if saving failed (e.g. offline, backend
      // hiccup) — they still made it through the 20 minutes either way.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that, but you still made it through.")),
        );
      }
    }
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.read(activeSessionControllerProvider)?.session.suggestedTask;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _outcome == null
                ? _SmokeQuestion(onChoose: _chooseOutcome)
                : _TaskQuestion(task: task, onChoose: _chooseTaskCompletion),
          ),
        ),
      ),
    );
  }
}

class _SmokeQuestion extends StatelessWidget {
  const _SmokeQuestion({required this.onChoose});

  final void Function(SessionOutcome outcome) onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What did you decide?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Either way, you made it through 20 minutes. That counts.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: "I didn't smoke",
          onPressed: () => onChoose(SessionOutcome.didNotSmoke),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => onChoose(SessionOutcome.smoked),
          child: const Text('I smoked'),
        ),
      ],
    );
  }
}

class _TaskQuestion extends StatelessWidget {
  const _TaskQuestion({required this.task, required this.onChoose});

  final TaskSuggestion? task;
  final void Function(bool completed) onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'One more thing',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          task == null
              ? 'Did you complete the suggested task?'
              : 'Did you complete: "${task!.title}"?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Yes, I did it',
          onPressed: () => onChoose(true),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => onChoose(false),
          child: const Text('Not this time'),
        ),
      ],
    );
  }
}
