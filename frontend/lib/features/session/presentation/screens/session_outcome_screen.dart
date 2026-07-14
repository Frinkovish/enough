import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/boo_avatar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/craving_session.dart';
import '../../domain/task_skip_reason.dart';
import '../../domain/task_suggestion.dart';
import '../providers/active_session_controller.dart';

/// Phrasing for the "what did you decide" question, tailored per addiction
/// so cigarette sessions still read as "smoked" while non-smoking ones
/// read as "used"/"stayed clean" instead.
extension _AddictionOutcomeCopy on AddictionType {
  String get usedLabel => this == AddictionType.cigarettes ? 'I smoked' : 'I used';
  String get stayedCleanLabel => this == AddictionType.cigarettes ? "I didn't smoke" : 'I stayed clean';
}

class SessionOutcomeScreen extends ConsumerStatefulWidget {
  const SessionOutcomeScreen({super.key});

  @override
  ConsumerState<SessionOutcomeScreen> createState() => _SessionOutcomeScreenState();
}

class _SessionOutcomeScreenState extends ConsumerState<SessionOutcomeScreen> {
  SessionOutcome? _outcome;
  bool? _taskCompleted;
  TaskSkipReason? _taskSkipReason;

  /// True once the skip-reason step has been shown and resolved (either a
  /// reason was picked, or the user skipped it) — distinct from
  /// [_taskSkipReason] being null, which is also true before that step
  /// has even been reached.
  bool _skipReasonResolved = false;

  void _chooseOutcome(SessionOutcome outcome) {
    setState(() => _outcome = outcome);
  }

  void _chooseTaskCompletion(bool completed) {
    setState(() => _taskCompleted = completed);
  }

  void _chooseSkipReason(TaskSkipReason reason) {
    setState(() {
      _taskSkipReason = reason;
      _skipReasonResolved = true;
    });
  }

  void _skipReasonStep() {
    setState(() => _skipReasonResolved = true);
  }

  Future<void> _finish() async {
    final outcome = _outcome;
    final completed = _taskCompleted;
    if (outcome == null || completed == null) return;
    try {
      await ref.read(activeSessionControllerProvider.notifier).recordOutcome(
            outcome,
            taskCompleted: completed,
            taskSkipReason: _taskSkipReason,
          );
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
    final session = ref.read(activeSessionControllerProvider)?.session;
    final task = session?.suggestedTask;
    final addictionType = session?.addictionType ?? AddictionType.cigarettes;

    Widget step;
    if (_outcome == null) {
      step = _OutcomeQuestion(addictionType: addictionType, onChoose: _chooseOutcome);
    } else if (_taskCompleted == null) {
      step = _TaskQuestion(task: task, onChoose: _chooseTaskCompletion);
    } else if (_taskCompleted == false && !_skipReasonResolved) {
      step = _TaskSkipReasonQuestion(onChoose: _chooseSkipReason, onSkip: _skipReasonStep);
    } else {
      // Celebrate any partial win — resisting the craving or doing the
      // task both count, even if the other one didn't go as hoped.
      final isWin = _outcome == SessionOutcome.stayedClean || _taskCompleted == true;
      step = _ReactionStep(isWin: isWin, onContinue: _finish);
    }

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: step,
          ),
        ),
      ),
    );
  }
}

class _OutcomeQuestion extends StatelessWidget {
  const _OutcomeQuestion({required this.addictionType, required this.onChoose});

  final AddictionType addictionType;
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
          label: addictionType.stayedCleanLabel,
          onPressed: () => onChoose(SessionOutcome.stayedClean),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => onChoose(SessionOutcome.used),
          child: Text(addictionType.usedLabel),
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

class _TaskSkipReasonQuestion extends StatelessWidget {
  const _TaskSkipReasonQuestion({required this.onChoose, required this.onSkip});

  final void Function(TaskSkipReason reason) onChoose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No worries — what got in the way?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Helps Boo suggest better tasks next time.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: TaskSkipReason.values
              .map((reason) => ChoiceChip(
                    label: Text(reason.label),
                    selected: false,
                    onSelected: (_) => onChoose(reason),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: onSkip, child: const Text('Skip')),
      ],
    );
  }
}

class _ReactionStep extends StatelessWidget {
  const _ReactionStep({required this.isWin, required this.onContinue});

  final bool isWin;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BooAvatar(
          size: 160,
          assetPath: isWin ? 'assets/images/boo_happy.jpg' : 'assets/images/boo_sad.png',
        ),
        const SizedBox(height: 24),
        Text(
          isWin ? 'Nice one!' : 'That happens sometimes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          isWin
              ? "Boo's proud of you — every one of these adds up."
              : "Boo's still on your side. Twenty minutes from now is another chance.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        PrimaryButton(label: 'Continue', onPressed: onContinue),
      ],
    );
  }
}
