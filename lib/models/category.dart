/// Representa uma categoria de conteúdo (ex: "Canais Abertos", "Filmes de Ação").
class Category {
  final String id;
  final String name;
  final String type; // 'live', 'movie' ou 'series'

  Category({
    required this.id,
    required this.name,
    required this.type,
  });

  factory Category.fromXtream({
    required Map<String, dynamic> json,
    required String type,
  }) {
    return Category(
      id: json['category_id'].toString(),
      name: json['category_name'] ?? 'Sem categoria',
      type: type,
    );
  }
}