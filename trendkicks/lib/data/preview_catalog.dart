import '../models/product_model.dart';

// Preview data is never used to create a live order. The same catalog is seeded in SQL.
final previewCatalog = <Product>[
  _shoe(
    1,
    'Air Force 1 ’07',
    'Nike',
    549500,
    'White',
    'nike-air.jpg',
    'An everyday icon. Clean leather, a classic low profile, and comfort that goes with everything.',
  ),
  _shoe(
    2,
    'Dunk Low Retro',
    'Nike',
    589500,
    'Black / White',
    'nike-dunk.jpg',
    'Court heritage meets everyday style. A timeless silhouette with a padded collar and a crisp two-tone finish.',
  ),
  _shoe(
    3,
    'Samba OG',
    'Adidas',
    680000,
    'White / Gum',
    'adidas-samba.jpg',
    'From the indoor pitch to your daily rotation. A low-profile classic with suede details and a gum outsole.',
  ),
  _shoe(
    4,
    'Suede Classic',
    'Puma',
    480000,
    'Forest Green',
    'puma-suede.jpg',
    'Soft suede and a street-ready shape. An enduring classic built for your own pace.',
  ),
  _shoe(
    5,
    'Air Max 90',
    'Nike',
    739500,
    'Sail / Orange',
    'nike-max.jpg',
    'Visible cushioning, layered textures, and a familiar shape. Made for long days and easy styling.',
  ),
  _shoe(
    6,
    'Campus 00s',
    'Adidas',
    650000,
    'Grey / White',
    'adidas-campus.jpg',
    'A fresh take on a terrace favorite. A chunky profile, soft upper, and unmistakable three-stripe detail.',
  ),
  _shoe(
    7,
    'RS-X Efekt',
    'Puma',
    620000,
    'Cream / Sand',
    'puma-rsx.jpg',
    'A bold, layered runner with a cushioned feel. Bring a little extra energy to your everyday rotation.',
  ),
  _shoe(
    8,
    'Gazelle Indoor',
    'Adidas',
    700000,
    'Blue / Gum',
    'adidas-gazelle.jpg',
    'Rich color, soft suede, and a translucent gum sole. A classic that keeps finding new ways to stand out.',
  ),
];

Product _shoe(
  int index,
  String name,
  String brand,
  int price,
  String color,
  String image,
  String description,
) => Product(
  id: '10000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
  name: name,
  brand: brand,
  description: description,
  priceCents: price,
  images: ['asset:assets/images/$image'],
  variants: [
    for (var size = 6; size <= 12; size++)
      ShoeVariant(
        id: '20000000-0000-0000-0000-${(index * 100 + size).toString().padLeft(12, '0')}',
        size: '$size',
        color: color,
        stock: size == 12 ? 0 : 8,
      ),
  ],
);
