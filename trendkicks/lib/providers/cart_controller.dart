import 'package:flutter/foundation.dart';

import '../core/ui.dart';
import '../models/commerce_models.dart';
import '../models/product_model.dart';
import '../services/store_backend.dart';

class CartController extends ChangeNotifier {
  CartController(this.backend);
  final StoreBackend backend;
  List<CartLine> lines = [];
  String? owner;
  String? error;
  bool busy = false;
  int _generation = 0;
  int get count => lines.fold(0, (sum, line) => sum + line.quantity);
  int get subtotalCents => lines.fold(0, (sum, line) => sum + line.totalCents);
  void setOwner(String? id) {
    if (id == owner) return;
    owner = id;
    ++_generation;
    lines = [];
    error = null;
    busy = false;
    // ProxyProvider is building here. Notify asynchronously after the provider tree settles.
    Future.microtask(refresh);
  }

  Future<void> refresh() async {
    final generation = _generation;
    final id = owner;
    if (id == null) {
      notifyListeners();
      return;
    }
    try {
      final result = await backend.cart();
      if (generation == _generation && id == owner) {
        lines = result;
        error = null;
      }
    } catch (e) {
      if (generation == _generation) error = friendlyError(e);
    }
    if (generation == _generation) notifyListeners();
  }

  Future<void> add(Product product, ShoeVariant variant, int quantity) async {
    final current = lines
        .where((line) => line.variant.id == variant.id)
        .firstOrNull;
    await setQuantity(product, variant, (current?.quantity ?? 0) + quantity);
  }

  Future<void> setQuantity(
    Product product,
    ShoeVariant variant,
    int quantity,
  ) async {
    if (busy) return;
    if (quantity < 0 ||
        quantity > 99 ||
        (quantity > 0 && (!product.active || quantity > variant.stock))) {
      throw StoreException(
        'That quantity is not available. Refresh the product and try again.',
      );
    }
    busy = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    try {
      if (owner != null) {
        await backend.setCart(variant.id, quantity);
        if (generation == _generation) await refresh();
      } else {
        lines = [
          for (final line in lines)
            if (line.variant.id != variant.id) line,
          if (quantity > 0)
            CartLine(product: product, variant: variant, quantity: quantity),
        ];
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }
}
