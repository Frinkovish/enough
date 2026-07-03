import 'product_idea.dart';

abstract class ProductIdeaRepository {
  Future<List<ProductIdea>> getIdeas();

  Future<void> addIdea({
    required IdeaType type,
    required String title,
    String description = '',
  });

  Future<void> setDone(String id, bool isDone);

  Future<void> updateIdea({
    required String id,
    required IdeaType type,
    required String title,
    String description = '',
  });

  Future<void> deleteIdea(String id);
}
