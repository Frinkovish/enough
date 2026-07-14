import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/boo_avatar.dart';
import '../../../../core/widgets/boo_loading.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/craving_intensity.dart';
import '../../domain/craving_trigger.dart';
import '../../domain/energy_level.dart';
import '../providers/active_session_controller.dart';

/// Boo's alignment for each step — he drifts left to right across the top
/// of the screen as the three questions progress, like he's walking the
/// user through them.
const _booAlignmentForStep = [
  Alignment(-0.55, -0.5),
  Alignment(0, -0.5),
  Alignment(0.55, -0.5),
];

/// Boo holds up the matching number of fingers for each question.
const _booAssetForStep = [
  'assets/images/boo_counting_1.png',
  'assets/images/boo_counting_2.png',
  'assets/images/boo_counting_3.png',
];

/// Three quick taps, one question at a time: what triggered this, how
/// much capacity is there right now, and how strong the urge is. Each
/// answer immediately advances to the next step. Once all three are
/// answered, this same screen starts the session (showing a Boo loading
/// animation while the AI suggestion call is in flight) and navigates to
/// the session screen itself — so there's no flicker back to the home
/// screen while waiting. Shown as a full-screen route (not a bottom
/// sheet) so Boo and the animated background have room to breathe.
Future<void> showCravingIntakeSheet(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, _, __) => const _CravingIntakeScreen(),
      transitionsBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _CravingIntakeScreen extends ConsumerStatefulWidget {
  const _CravingIntakeScreen();

  @override
  ConsumerState<_CravingIntakeScreen> createState() => _CravingIntakeScreenState();
}

class _CravingIntakeScreenState extends ConsumerState<_CravingIntakeScreen> {
  static const _stepCount = 3;

  /// False until the addiction type for this craving is settled — either
  /// skipped (Total control off / at most one addiction type on the
  /// profile, so there's nothing to ask) or answered via the picker step.
  bool _addictionResolved = false;
  bool _addictionPickerShown = false;
  AddictionType _addictionType = AddictionType.cigarettes;

  int _step = 0;
  bool _loading = false;
  CravingTrigger? _trigger;
  EnergyLevel? _energy;

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else if (_addictionPickerShown) {
      setState(() => _addictionResolved = false);
    }
  }

  void _selectAddictionType(AddictionType type) {
    setState(() {
      _addictionType = type;
      _addictionResolved = true;
    });
  }

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

  Future<void> _selectIntensity(CravingIntensity intensity) async {
    setState(() => _loading = true);
    await ref.read(activeSessionControllerProvider.notifier).startSession(
          _trigger!,
          _energy!,
          intensity,
          addictionType: _addictionType,
        );
    if (mounted) context.go(AppRoutes.session);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: AnimatedGradientBackground()),
            Center(child: BooLoading(label: 'Finding the right next step…')),
          ],
        ),
      );
    }

    if (!_addictionResolved) {
      final profileAsync = ref.watch(userProfileProvider);
      if (profileAsync.isLoading) {
        return const Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: AnimatedGradientBackground()),
              Center(child: BooLoading(label: 'One sec…')),
            ],
          ),
        );
      }

      // Any error is treated the same as "no profile yet" — fail open to
      // the pre-Total-control default rather than blocking the craving flow.
      final profile = profileAsync.valueOrNull;
      final choices = (profile?.totalControl ?? false) ? profile!.addictionTypes : const <AddictionType>[];
      if (choices.length > 1) {
        return _buildAddictionPicker(context, choices);
      }
      _addictionType = choices.length == 1 ? choices.single : AddictionType.cigarettes;
      _addictionResolved = true;
    }

    final String question;
    final List<Widget> chips;
    switch (_step) {
      case 0:
        question = 'What triggered this?';
        chips = CravingTrigger.values
            .where((t) => t != CravingTrigger.other)
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

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedGradientBackground()),
          AnimatedAlign(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            alignment: _booAlignmentForStep[_step],
            child: SafeArea(child: BooAvatar(assetPath: _booAssetForStep[_step])),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: _step > 0 || _addictionPickerShown
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
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
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
            ),
          ),
        ],
      ),
    );
  }

  /// Shown before the usual trigger/energy/intensity questions when
  /// Total control is on and the profile has more than one addiction type
  /// — otherwise there's nothing to ask and [_addictionType] is resolved
  /// automatically.
  Widget _buildAddictionPicker(BuildContext context, List<AddictionType> choices) {
    _addictionPickerShown = true;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedGradientBackground()),
          const SafeArea(
            child: Align(
              alignment: Alignment(-0.85, -0.5),
              child: BooAvatar(assetPath: 'assets/images/boo.png'),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            'Which one is this?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: choices
                          .map((type) => ChoiceChip(
                                label: Text(type.label),
                                selected: false,
                                onSelected: (_) => _selectAddictionType(type),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
