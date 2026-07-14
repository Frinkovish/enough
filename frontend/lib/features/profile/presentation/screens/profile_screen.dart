import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _occupationController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _birthdate;
  Gender? _gender;
  final Set<QuitReason> _quitReasons = {};
  final Set<AddictionType> _addictionTypes = {};
  bool _totalControl = false;

  /// Defaults to today so the days-clean counter reads 0 for a brand new
  /// profile, rather than needing a null check everywhere it's used.
  DateTime _quitDate = DateTime.now();
  int? _daysCleanTarget;
  bool _loaded = false;
  bool _sendingTestReminder = false;

  int get _daysClean {
    final today = DateTime.now();
    final start = DateTime(_quitDate.year, _quitDate.month, _quitDate.day);
    final end = DateTime(today.year, today.month, today.day);
    return end.difference(start).inDays;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _loadFrom(UserProfile? profile) {
    if (_loaded || profile == null) return;
    _loaded = true;
    _nameController.text = profile.displayName ?? '';
    _occupationController.text = profile.occupation ?? '';
    _birthdate = profile.birthdate;
    _gender = profile.gender;
    _quitReasons.addAll(profile.quitReasons);
    _addictionTypes.addAll(profile.addictionTypes);
    _totalControl = profile.totalControl;
    _quitDate = profile.quitDate ?? _quitDate;
    _daysCleanTarget = profile.daysCleanTarget;
    _targetController.text = _daysCleanTarget?.toString() ?? '';
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final targetText = _targetController.text.trim();
    final target = targetText.isEmpty ? null : int.tryParse(targetText);

    await ref.read(profileControllerProvider.notifier).saveProfile(
          UserProfile(
            userId: userId,
            displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            birthdate: _birthdate,
            occupation: _occupationController.text.trim().isEmpty ? null : _occupationController.text.trim(),
            gender: _gender,
            quitReasons: _quitReasons.toList(),
            addictionTypes: _addictionTypes.toList(),
            totalControl: _totalControl,
            quitDate: _quitDate,
            daysCleanTarget: target,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    }
  }

  Future<void> _confirmResetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all stats?'),
        content: const Text(
          'Your craving session history, streaks, and trend charts will be cleared, and your '
          "days-clean counter will restart from today. This can't be undone. Monthly goals and "
          "your days-clean target aren't affected.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(profileControllerProvider.notifier).resetStats();
    setState(() => _quitDate = DateTime.now());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stats reset.')));
    }
  }

  Future<void> _sendTestReminder() async {
    setState(() => _sendingTestReminder = true);
    try {
      await ref.read(reminderRepositoryProvider).sendTestReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test reminder sent.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't send it — check the backend logs.")));
      }
    } finally {
      if (mounted) setState(() => _sendingTestReminder = false);
    }
  }

  String _formatDate(DateTime date) => date.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? '';
    final profileAsync = ref.watch(userProfileProvider);
    final isSaving = ref.watch(profileControllerProvider).isLoading;

    ref.listen(profileControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        data: (profile) {
          _loadFrom(profile);
          return _buildForm(context, email, isSaving);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildForm(context, email, isSaving),
      ),
    );
  }

  Widget _buildForm(BuildContext context, String email, bool isSaving) {
    final maxGoals = ref.watch(maxGoalsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Days clean', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _daysCleanTarget == null ? '$_daysClean days' : '$_daysClean / $_daysCleanTarget days',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_daysCleanTarget != null && _daysCleanTarget! > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_daysClean / _daysCleanTarget!).clamp(0, 1).toDouble(),
                        minHeight: 8,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Since ${_formatDate(_quitDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target (days)', hintText: 'e.g. 30'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Goals', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Active goal limit', style: Theme.of(context).textTheme.bodyMedium)),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                  ButtonSegment(value: 7, label: Text('7')),
                  ButtonSegment(value: 10, label: Text('10')),
                ],
                selected: {maxGoals},
                onSelectionChanged: (selection) =>
                    ref.read(maxGoalsProvider.notifier).set(selection.first),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: email,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickBirthdate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Birthdate'),
              child: Text(_birthdate == null ? 'Tap to set' : _formatDate(_birthdate!)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _occupationController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Work'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Gender>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: Gender.values
                .map((gender) => DropdownMenuItem(value: gender, child: Text(gender.label)))
                .toList(),
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 20),
          Text('Why are you quitting?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuitReason.values.map((reason) {
              return FilterChip(
                label: Text(reason.label),
                selected: _quitReasons.contains(reason),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _quitReasons.add(reason);
                    } else {
                      _quitReasons.remove(reason);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('What are you working on?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AddictionType.values.map((type) {
              return FilterChip(
                label: Text(type.label),
                selected: _addictionTypes.contains(type),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _addictionTypes.add(type);
                    } else {
                      _addictionTypes.remove(type);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Total control'),
            subtitle: const Text(
              "When on, logging a craving asks which of the above it's for. "
              'When off, cravings are always logged as cigarettes.',
            ),
            value: _totalControl,
            onChanged: (value) => setState(() => _totalControl = value),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', isLoading: isSaving, onPressed: _save),
          if (isAdmin) ...[
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 16),
            Text('Dev tools', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _sendingTestReminder ? null : _sendTestReminder,
              child: Text(_sendingTestReminder ? 'Sending…' : 'Send test reminder'),
            ),
          ],
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 16),
          Text('Danger zone', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: isSaving ? null : _confirmResetStats,
            child: const Text('Reset all stats'),
          ),
        ],
      ),
    );
  }
}
