import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/supabase_product_idea_repository.dart';
import '../../domain/product_idea.dart';
import '../../domain/product_idea_repository.dart';

final productIdeaRepositoryProvider = Provider<ProductIdeaRepository>((ref) {
  return SupabaseProductIdeaRepository(ref.watch(supabaseClientProvider));
});

final productIdeasProvider = FutureProvider<List<ProductIdea>>((ref) {
  return ref.watch(productIdeaRepositoryProvider).getIdeas();
});

class AdminIdeasController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addIdea({
    required IdeaType type,
    required String title,
    String description = '',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(productIdeaRepositoryProvider).addIdea(type: type, title: title, description: description);
      ref.invalidate(productIdeasProvider);
    });
  }

  Future<void> toggleDone(ProductIdea idea) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(productIdeaRepositoryProvider).setDone(idea.id, !idea.isDone);
      ref.invalidate(productIdeasProvider);
    });
  }

  Future<void> deleteIdea(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(productIdeaRepositoryProvider).deleteIdea(id);
      ref.invalidate(productIdeasProvider);
    });
  }
}

final adminIdeasControllerProvider = AsyncNotifierProvider<AdminIdeasController, void>(AdminIdeasController.new);
