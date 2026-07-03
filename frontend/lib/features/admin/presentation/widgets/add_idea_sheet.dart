import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/primary_button.dart';
import '../../domain/product_idea.dart';
import '../providers/admin_providers.dart';

Future<void> showAddIdeaSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _IdeaSheet(),
  );
}

Future<void> showEditIdeaSheet(BuildContext context, ProductIdea idea) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _IdeaSheet(idea: idea),
  );
}

// ignore: unused_element — kept for external callers via showAddIdeaSheet / showEditIdeaSheet
class AddIdeaSheet extends StatelessWidget {
  const AddIdeaSheet({super.key});

  @override
  Widget build(BuildContext context) => const _IdeaSheet();
}

class _IdeaSheet extends ConsumerStatefulWidget {
  const _IdeaSheet({this.idea});

  final ProductIdea? idea;

  @override
  ConsumerState<_IdeaSheet> createState() => _IdeaSheetState();
}

class _IdeaSheetState extends ConsumerState<_IdeaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.idea?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.idea?.description ?? '');
  late IdeaType _type = widget.idea?.type ?? IdeaType.newFeature;

  bool get _isEdit => widget.idea != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(adminIdeasControllerProvider.notifier);
    if (_isEdit) {
      await notifier.updateIdea(
        id: widget.idea!.id,
        type: _type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );
    } else {
      await notifier.addIdea(
        type: _type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminIdeasControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        ),
      );
    });

    final isLoading = ref.watch(adminIdeasControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit idea' : 'New idea',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<IdeaType>(
                segments: const [
                  ButtonSegment(value: IdeaType.newFeature, label: Text('NEW')),
                  ButtonSegment(value: IdeaType.fix, label: Text('FIX')),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save', isLoading: isLoading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
