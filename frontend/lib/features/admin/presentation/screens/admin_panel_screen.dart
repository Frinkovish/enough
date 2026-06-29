import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/product_idea.dart';
import '../providers/admin_providers.dart';
import '../widgets/add_idea_sheet.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  IdeaType? _filter;

  @override
  Widget build(BuildContext context) {
    final ideasAsync = ref.watch(productIdeasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Product backlog')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddIdeaSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<IdeaType?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(value: IdeaType.newFeature, label: Text('NEW')),
                ButtonSegment(value: IdeaType.fix, label: Text('FIX')),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) => setState(() => _filter = selection.first),
            ),
          ),
          Expanded(
            child: ideasAsync.when(
              data: (ideas) {
                final filtered =
                    _filter == null ? ideas : ideas.where((idea) => idea.type == _filter).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No ideas yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _IdeaTile(idea: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => const Center(child: Text('Something went wrong.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdeaTile extends ConsumerWidget {
  const _IdeaTile({required this.idea});

  final ProductIdea idea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(idea.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => ref.read(adminIdeasControllerProvider.notifier).deleteIdea(idea.id),
      child: ListTile(
        leading: Checkbox(
          value: idea.isDone,
          onChanged: (_) => ref.read(adminIdeasControllerProvider.notifier).toggleDone(idea),
        ),
        title: Text(
          idea.title,
          style: idea.isDone ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: idea.description.isEmpty ? null : Text(idea.description),
        trailing: Chip(
          label: Text(idea.type.label),
          backgroundColor:
              idea.type == IdeaType.fix ? colorScheme.errorContainer : colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: idea.type == IdeaType.fix ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
