import 'package:flutter/material.dart';

import '../../domain/craving_intensity.dart';
import '../../domain/craving_trigger.dart';
import '../../domain/energy_level.dart';

typedef CravingIntake = ({CravingTrigger trigger, EnergyLevel energy, CravingIntensity intensity});

/// Three quick taps, one question at a time: what triggered this, how
/// much capacity is there right now, and how strong the urge is. Each
/// answer immediately advances to the next step — still just three taps
/// total, but each question gets full visual focus rather than being
/// crammed into one screen.
Future<CravingIntake?> showCravingIntakeSheet(BuildContext context) {
  return showModalBottomSheet<CravingIntake>(
    context: context,
    showDragHandle: true,
    isDismissible: true,
    builder: (context) => const _CravingIntakeSheet(),
  );
}

class _CravingIntakeSheet extends StatefulWidget {
  const _CravingIntakeSheet();

  @override
  State<_CravingIntakeSheet> createState() => _CravingIntakeSheetState();
}

class _CravingIntakeSheetState extends State<_CravingIntakeSheet> {
  static const _stepCount = 3;

  int _step = 0;
  CravingTrigger? _trigger;
  EnergyLevel? _energy;

  void _back() => setState(() => _step -= 1);

  void _selectTrigger(CravingTrigger trigger) {
    setState(() {
      _trigger = trigger;
      _step = 1;
    });
  }

  void _selectEnergy(EnergyLevel energy) {
    setState(() {
      _energy = energy;
      _step = 2;
    });
  }

  void _selectIntensity(CravingIntensity intensity) {
    Navigator.of(context).pop((trigger: _trigger!, energy: _energy!, intensity: intensity));
  }

  @override
  Widget build(BuildContext context) {
    final String question;
    final List<Widget> chips;
    switch (_step) {
      case 0:
        question = 'What triggered this?';
        chips = CravingTrigger.values
            .map((trigger) => ChoiceChip(
                  label: Text(trigger.label),
                  selected: false,
                  onSelected: (_) => _selectTrigger(trigger),
                ))
            .toList();
      case 1:
        question = "What's your energy like right now?";
        chips = EnergyLevel.values
            .map((energy) => ChoiceChip(
                  label: Text(energy.label),
                  selected: false,
                  onSelected: (_) => _selectEnergy(energy),
                ))
            .toList();
      default:
        question = 'How strong is the craving?';
        chips = CravingIntensity.values
            .map((intensity) => ChoiceChip(
                  label: Text(intensity.label),
                  selected: false,
                  onSelected: (_) => _selectIntensity(intensity),
                ))
            .toList();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: _step > 0
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back, size: 20),
                          onPressed: _back,
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    question,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_stepCount, (index) {
                final isActive = index == _step;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: chips,
            ),
          ],
        ),
      ),
    );
  }
}
