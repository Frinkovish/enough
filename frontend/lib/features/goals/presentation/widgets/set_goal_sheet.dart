import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/goal_repository.dart';
import '../providers/goal_providers.dart';

Future<void> showSetGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const SetGoalSheet(),
  );
}

class SetGoalSheet extends ConsumerStatefulWidget {
  const SetGoalSheet({super.key});

  @override
  ConsumerState<SetGoalSheet> createState() => _SetGoalSheetState();
}

class _SetGoalSheetState extends ConsumerState<SetGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(goalControllerProvider.notifier)
        .createGoalFromDescription(_descriptionController.text.trim());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(goalControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        ),
      );
    });

    final isLoading = ref.watch(goalControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New goal',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                "Describe it in your own words — we'll figure out how to measure it.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'e.g. Run 5 km this month'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save goal', isLoading: isLoading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final maxGoals = ref.read(maxGoalsProvider);
    return error is TooManyActiveGoalsError
        ? "You've reached the limit of $maxGoals active goals."
        : 'Something went wrong. Please try again.';
  }
}
