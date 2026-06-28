import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
  DateTime? _birthdate;
  Gender? _gender;
  final Set<QuitReason> _quitReasons = {};
  bool _loaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
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

    await ref.read(profileControllerProvider.notifier).saveProfile(
          UserProfile(
            userId: userId,
            displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            birthdate: _birthdate,
            occupation: _occupationController.text.trim().isEmpty ? null : _occupationController.text.trim(),
            gender: _gender,
            quitReasons: _quitReasons.toList(),
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
          'Your craving session history, streaks, and trend charts will be cleared. '
          'This can\'t be undone. Monthly goals are not affected.',
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stats reset.')));
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          PrimaryButton(label: 'Save', isLoading: isSaving, onPressed: _save),
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
