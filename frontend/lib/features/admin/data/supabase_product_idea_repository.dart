import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/product_idea.dart';
import '../domain/product_idea_repository.dart';

class SupabaseProductIdeaRepository implements ProductIdeaRepository {
  SupabaseProductIdeaRepository(this._client);

  final SupabaseClient _client;
  final _uuid = const Uuid();

  static const _table = 'product_ideas';

  ProductIdea _fromRow(Map<String, dynamic> row) {
    return ProductIdea(
      id: row['id'] as String,
      type: IdeaTypeLabel.fromWire(row['type'] as String),
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      isDone: row['is_done'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<List<ProductIdea>> getIdeas() async {
    final rows = await _client.from(_table).select().order('created_at', ascending: false);
    return (rows as List).map((row) => _fromRow(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> addIdea({
    required IdeaType type,
    required String title,
    String description = '',
  }) async {
    await _client.from(_table).insert({
      'id': _uuid.v4(),
      'type': type.wireValue,
      'title': title,
      'description': description,
      'is_done': false,
    });
  }

  @override
  Future<void> setDone(String id, bool isDone) async {
    await _client.from(_table).update({'is_done': isDone}).eq('id', id);
  }

  @override
  Future<void> updateIdea({
    required String id,
    required IdeaType type,
    required String title,
    String description = '',
  }) async {
    await _client.from(_table).update({
      'type': type.wireValue,
      'title': title,
      'description': description,
    }).eq('id', id);
  }

  @override
  Future<void> deleteIdea(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
