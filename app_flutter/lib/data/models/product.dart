class Product {
  final int id;
  final String title;
  final double price;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      updatedAt: DateTime.now(),
    );
  }
}
