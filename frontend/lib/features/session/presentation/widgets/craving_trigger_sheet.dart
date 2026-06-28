import 'package:flutter/material.dart';

import '../../domain/craving_trigger.dart';

/// One tap, no questionnaire: asks what triggered the craving so the
/// app can learn the user's patterns over time, without adding the
/// setup friction a full form would.
Future<CravingTrigger?> showCravingTriggerSheet(BuildContext context) {
  return showModalBottomSheet<CravingTrigger>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What triggered this?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: CravingTrigger.values.map((trigger) {
                  return ChoiceChip(
                    label: Text(trigger.label),
                    selected: false,
                    onSelected: (_) => Navigator.of(context).pop(trigger),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
