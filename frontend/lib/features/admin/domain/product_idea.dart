enum IdeaType { newFeature, fix }

extension IdeaTypeLabel on IdeaType {
  String get label {
    switch (this) {
      case IdeaType.newFeature:
        return 'NEW';
      case IdeaType.fix:
        return 'FIX';
    }
  }

  String get wireValue {
    switch (this) {
      case IdeaType.newFeature:
        return 'new';
      case IdeaType.fix:
        return 'fix';
    }
  }

  static IdeaType fromWire(String value) {
    return value == 'fix' ? IdeaType.fix : IdeaType.newFeature;
  }
}

class ProductIdea {
  const ProductIdea({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.isDone = false,
    required this.createdAt,
  });

  final String id;
  final IdeaType type;
  final String title;
  final String description;
  final bool isDone;
  final DateTime createdAt;

  ProductIdea copyWith({IdeaType? type, String? title, String? description, bool? isDone}) {
    return ProductIdea(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }
}
