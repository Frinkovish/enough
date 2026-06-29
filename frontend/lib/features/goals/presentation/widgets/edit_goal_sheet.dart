import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/primary_button.dart';
import '../../domain/monthly_goal.dart';
import '../providers/goal_providers.dart';

Future<void> showEditGoalSheet(BuildContext context, MonthlyGoal goal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => EditGoalSheet(goal: goal),
  );
}

class EditGoalSheet extends ConsumerStatefulWidget {
  const EditGoalSheet({super.key, required this.goal});

  final MonthlyGoal goal;

  @override
  ConsumerState<EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends ConsumerState<EditGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.goal.title);
  late final _targetController = TextEditingController(text: widget.goal.target.formatted);
  late final _unitController = TextEditingController(text: widget.goal.unit);

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(goalControllerProvider.notifier).updateGoal(
          goalId: widget.goal.id,
          title: _titleController.text.trim(),
          target: num.parse(_targetController.text.trim()),
          unit: _unitController.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(goalControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
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
                'Edit goal',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Run'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Target', labelText: 'Target'),
                      validator: (value) {
                        final parsed = num.tryParse(value?.trim() ?? '');
                        return (parsed == null || parsed < 1) ? 'Enter a number' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(hintText: 'km, books...', labelText: 'Unit'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save changes', isLoading: isLoading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
