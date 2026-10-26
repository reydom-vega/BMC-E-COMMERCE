import 'package:flutter/foundation.dart';

import '../data/preview_catalog.dart';
import '../models/product_model.dart';
import '../services/store_backend.dart';

class CatalogController extends ChangeNotifier {
  CatalogController(this.backend) {
    load();
  }
  final StoreBackend backend;
  List<Product> products = [];
  bool loading = true;
  bool live = false;
  String? error;
  int revision = 0;
  int _generation = 0;
  bool _disposed = false;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    if (backend.preview) {
      products = previewCatalog;
      live = false;
    } else {
      try {
        final fresh = await backend.products();
        if (_disposed || generation != _generation) return;
        products = fresh;
        live = true;
      } catch (_) {
        if (_disposed || generation != _generation) return;
        error = 'The live catalog is unavailable. Showing the catalog preview.';
        products = previewCatalog;
        live = false;
      }
    }
    loading = false;
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
