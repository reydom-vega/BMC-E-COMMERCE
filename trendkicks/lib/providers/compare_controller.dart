import 'package:flutter/foundation.dart';

import '../core/ui.dart';
import '../models/product_model.dart';

class CompareController extends ChangeNotifier {
  final List<Product> _products = [];
  List<Product> get products => List.unmodifiable(_products);
  bool contains(String id) => _products.any((p) => p.id == id);
  void toggle(Product product) {
    if (contains(product.id)) {
      _products.removeWhere((p) => p.id == product.id);
    } else {
      if (_products.length >= 3) {
        throw StoreException('Compare up to three sneakers. Remove one first.');
      }
      _products.add(product);
    }
    notifyListeners();
  }
}

final sneakerComparison = CompareController();
