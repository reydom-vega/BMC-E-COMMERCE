import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/ui.dart';
import '../services/store_backend.dart';

class WishlistController extends ChangeNotifier {
  WishlistController(this.backend);
  final StoreBackend backend;
  static const guestKey = 'trendkicks.guestWishlist';
  String? owner;
  Set<String> ids = {};
  final Set<String> busy = {};
  bool loading = true, _initialized = false, _disposed = false;
  String? error;
  int _generation = 0;
  bool contains(String id) => ids.contains(id);
  void setOwner(String? id) {
    if (_initialized && owner == id) return;
    _initialized = true;
    owner = id;
    ++_generation;
    ids = {};
    busy.clear();
    error = null;
    loading = true;
    // ProxyProvider updates happen while the tree is building.
    Future.microtask(refresh);
  }

  Future<void> refresh() async {
    if (_disposed || busy.isNotEmpty) return;
    final generation = ++_generation;
    final id = owner;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final saved = id == null
          ? ((await SharedPreferences.getInstance()).getStringList(guestKey) ??
                    [])
                .toSet()
          : await backend.wishlistIds(id);
      if (!_disposed && generation == _generation) ids = saved;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = id == null
            ? 'Device storage is unavailable. Please try again.'
            : friendlyError(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggle(String productId) async {
    if (!canToggle(productId)) return;
    if (error != null) {
      throw StoreException('Refresh your wishlist before saving a pair.');
    }
    final generation = _generation;
    final id = owner;
    final save = !ids.contains(productId);
    busy.add(productId);
    notifyListeners();
    try {
      if (id == null) {
        // Serialize guest writes by disabling all guest hearts during a write.
        final next = {...ids};
        save ? next.add(productId) : next.remove(productId);
        final stored = await (await SharedPreferences.getInstance())
            .setStringList(guestKey, next.toList());
        if (!stored) {
          throw StoreException(
            'Couldn’t save this pair on your device. Please try again.',
          );
        }
      } else {
        await backend.setWishlisted(id, productId, save);
      }
      if (!_disposed && generation == _generation) {
        ids = {...ids};
        save ? ids.add(productId) : ids.remove(productId);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy.remove(productId);
        notifyListeners();
      }
    }
  }

  bool canToggle(String id) =>
      !loading && !busy.contains(id) && (owner != null || busy.isEmpty);
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
