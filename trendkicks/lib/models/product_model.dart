const shoeCategories = [
  'Lifestyle',
  'Running',
  'Training',
  'Basketball',
  'Skate',
  'Walking',
  'Other',
];

class ShoeVariant {
  const ShoeVariant({
    required this.id,
    required this.size,
    required this.color,
    required this.stock,
  });
  final String id;
  final String size;
  final String color;
  final int stock;
  factory ShoeVariant.fromMap(Map<String, dynamic> map) => ShoeVariant(
    id: map['id'].toString(),
    size: map['size'].toString(),
    color: map['color'] as String,
    stock: (map['stock'] as num).toInt(),
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.priceCents,
    required this.images,
    required this.variants,
    this.rating = 0,
    this.reviewCount = 0,
    this.active = true,
    this.category = 'Lifestyle',
    this.fitNotes = '',
  });
  final String id;
  final String name;
  final String brand;
  final String description;
  final int priceCents;
  final List<String> images;
  final List<ShoeVariant> variants;
  final double rating;
  final int reviewCount;
  final bool active;
  final String category, fitNotes;
  String get imageUrl => images.isEmpty ? '' : images.first;
  int get stock => variants.fold(0, (sum, v) => sum + v.stock);
  List<String> get colors => variants.map((v) => v.color).toSet().toList();
  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'].toString(),
    name: map['name'] as String,
    brand: map['brand'] as String,
    description: map['description'] as String? ?? '',
    priceCents: (map['price_cents'] as num).toInt(),
    images: List<String>.from(map['images'] ?? []),
    variants: (map['tk_variants'] as List? ?? [])
        .map((v) => ShoeVariant.fromMap(Map<String, dynamic>.from(v)))
        .toList(),
    rating: (map['rating'] as num? ?? 0).toDouble(),
    reviewCount: (map['review_count'] as num? ?? 0).toInt(),
    active: map['active'] as bool? ?? true,
    category: map['category'] as String? ?? 'Lifestyle',
    fitNotes: map['fit_notes'] as String? ?? '',
  );
}

enum ProductSort { recommended, highestRated, lowestRated, priceLow, priceHigh }

class CatalogFilters {
  const CatalogFilters({
    this.category = 'All',
    this.size = 'All',
    this.color = 'All',
    this.minPriceCents,
    this.maxPriceCents,
    this.inStockOnly = false,
  });
  final String category, size, color;
  final int? minPriceCents, maxPriceCents;
  final bool inStockOnly;
  int get count => [
    category != 'All',
    size != 'All',
    color != 'All',
    minPriceCents != null || maxPriceCents != null,
    inStockOnly,
  ].where((value) => value).length;
  CatalogFilters copyWith({
    String? category,
    String? size,
    String? color,
    int? minPriceCents,
    int? maxPriceCents,
    bool clearPrice = false,
    bool? inStockOnly,
  }) => CatalogFilters(
    category: category ?? this.category,
    size: size ?? this.size,
    color: color ?? this.color,
    minPriceCents: clearPrice ? null : minPriceCents ?? this.minPriceCents,
    maxPriceCents: clearPrice ? null : maxPriceCents ?? this.maxPriceCents,
    inStockOnly: inStockOnly ?? this.inStockOnly,
  );
  List<Product> apply(
    List<Product> products, {
    String search = '',
    String brand = 'All',
    ProductSort sort = ProductSort.recommended,
  }) => filterProducts(
    products,
    search: search,
    brand: brand,
    sort: sort,
    category: category,
    size: size == 'All' ? null : size,
    color: color == 'All' ? null : color,
    minPriceCents: minPriceCents,
    maxPriceCents: maxPriceCents,
    inStockOnly: inStockOnly,
  );
}

List<Product> filterProducts(
  List<Product> products, {
  String search = '',
  String brand = 'All',
  ProductSort sort = ProductSort.recommended,
  String category = 'All',
  String? size,
  String? color,
  int? minPriceCents,
  int? maxPriceCents,
  bool inStockOnly = false,
}) {
  final query = search.trim().toLowerCase();
  final result = products
      .where(
        (p) =>
            p.active &&
            (brand == 'All' || p.brand == brand) &&
            (category == 'All' || p.category == category) &&
            (minPriceCents == null || p.priceCents >= minPriceCents) &&
            (maxPriceCents == null || p.priceCents <= maxPriceCents) &&
            '${p.name} ${p.brand} ${p.category}'.toLowerCase().contains(
              query,
            ) &&
            (!(inStockOnly || size != null || color != null) ||
                p.variants.any(
                  (v) =>
                      v.stock > 0 &&
                      (size == null || v.size == size) &&
                      (color == null ||
                          v.color.toLowerCase() == color.toLowerCase()),
                )),
      )
      .toList();
  switch (sort) {
    case ProductSort.recommended:
      break;
    case ProductSort.highestRated:
      result.sort((a, b) => b.rating.compareTo(a.rating));
    case ProductSort.lowestRated:
      result.sort((a, b) => a.rating.compareTo(b.rating));
    case ProductSort.priceLow:
      result.sort((a, b) => a.priceCents.compareTo(b.priceCents));
    case ProductSort.priceHigh:
      result.sort((a, b) => b.priceCents.compareTo(a.priceCents));
  }
  return result;
}
