import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui.dart';
import '../models/commerce_models.dart';
import '../models/product_model.dart';

class StoreBackend {
  StoreBackend(this.client);
  final SupabaseClient? client;
  bool get preview => client == null;
  SupabaseClient get db =>
      client ??
      (throw StoreException(
        'Accounts and checkout are unavailable in this catalog preview.',
      ));
  String get userId =>
      db.auth.currentUser?.id ??
      (throw StoreException('Please sign in to continue.'));

  Future<List<Product>> products({bool admin = false}) async {
    final rows = admin
        ? await db
              .from('tk_products')
              .select('*, tk_variants(*)')
              .order('created_at')
        : await db
              .from('tk_products')
              .select('*, tk_variants(*)')
              .eq('active', true)
              .order('created_at');
    return rows.map(Product.fromMap).toList();
  }

  Future<Set<String>> wishlistIds(String owner) async {
    if (userId != owner) throw StoreException('Please sign in again.');
    final rows = await db
        .from('tk_wishlist')
        .select('product_id')
        .eq('user_id', owner);
    return rows.map((row) => row['product_id'] as String).toSet();
  }

  Future<void> setWishlisted(String owner, String productId, bool saved) async {
    if (userId != owner) {
      throw StoreException('Your account changed. Please try again.');
    }
    if (saved) {
      await db
          .from('tk_wishlist')
          .upsert(
            {'user_id': owner, 'product_id': productId},
            onConflict: 'user_id,product_id',
            ignoreDuplicates: true,
          );
    } else {
      await db
          .from('tk_wishlist')
          .delete()
          .eq('user_id', owner)
          .eq('product_id', productId);
    }
  }

  Future<CustomerProfile> profile() async {
    final id = userId;
    final row = await db.from('tk_profiles').select().eq('id', id).single();
    final admin = await db.rpc('tk_is_admin') as bool;
    return CustomerProfile.fromMap(row, isAdmin: admin);
  }

  Future<void> saveProfile(Map<String, dynamic> values) async {
    await db.from('tk_profiles').update(values).eq('id', userId);
  }

  Future<List<CartLine>> cart() async {
    final rows = await db
        .from('tk_cart')
        .select('quantity, tk_variants(*, tk_products(*))')
        .eq('user_id', userId)
        .order('created_at');
    return rows.map((row) {
      final variant = Map<String, dynamic>.from(row['tk_variants']);
      final product = Map<String, dynamic>.from(variant['tk_products']);
      product['tk_variants'] = [variant];
      return CartLine(
        product: Product.fromMap(product),
        variant: ShoeVariant.fromMap(variant),
        quantity: row['quantity'] as int,
      );
    }).toList();
  }

  Future<void> setCart(String variantId, int quantity) async => await db.rpc(
    'tk_set_cart',
    params: {'p_variant': variantId, 'p_quantity': quantity},
  );

  Future<int> shippingFee() async {
    final row = await db
        .from('tk_settings')
        .select('shipping_cents')
        .eq('id', 1)
        .single();
    return row['shipping_cents'] as int;
  }

  Future<List<StoreOrder>> orders({bool admin = false}) async {
    final query = db.from('tk_orders').select();
    final rows = admin
        ? await query.order('created_at', ascending: false)
        : await query
              .eq('user_id', userId)
              .order('created_at', ascending: false);
    return rows.map(StoreOrder.new).toList();
  }

  Future<StoreOrder> order(String id) async =>
      StoreOrder(await db.from('tk_orders').select().eq('id', id).single());
  Future<List<Map<String, dynamic>>> refunds({String? orderId}) async {
    final query = db.from('tk_refunds').select();
    return orderId == null
        ? await query.order('created_at', ascending: false)
        : await query
              .eq('order_id', orderId)
              .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> reviews(String productId) async => await db
      .from('tk_reviews')
      .select('id, rating, content, author_name, created_at')
      .eq('product_id', productId)
      .order('created_at', ascending: false);
  Future<Map<String, dynamic>?> myReview(String orderId, String itemId) async {
    final result = await db.rpc(
      'tk_my_review',
      params: {'p_order': orderId, 'p_item': itemId},
    );
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  Future<void> review(
    String orderId,
    String itemId,
    int rating,
    String content,
  ) async => await db.rpc(
    'tk_submit_review',
    params: {
      'p_order': orderId,
      'p_item': itemId,
      'p_rating': rating,
      'p_content': content,
    },
  );
  Future<void> requestRefund(
    String orderId,
    String itemId,
    String reason,
  ) async => await db.rpc(
    'tk_request_refund',
    params: {'p_order': orderId, 'p_item': itemId, 'p_reason': reason},
  );
  Future<List<Map<String, dynamic>>> notifications() async => await db
      .from('tk_notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  Future<void> readNotification(String id) async =>
      await db.rpc('tk_read_notification', params: {'p_id': id});
  Future<void> advanceOrder(String id, String status) async => await db.rpc(
    'tk_advance_order',
    params: {'p_order': id, 'p_status': status},
  );
  Future<void> decideRefund(String id, bool approved) async => await db.rpc(
    'tk_decide_refund',
    params: {'p_refund': id, 'p_approved': approved},
  );
  Future<void> archiveProduct(String id) async =>
      await db.rpc('tk_archive_product', params: {'p_id': id});
  Future<void> saveProduct(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> variants,
  ) async => await db.rpc(
    'tk_save_product',
    params: {'p_product': product, 'p_variants': variants},
  );
  Future<String> uploadImage(Uint8List bytes, String extension) async {
    if (bytes.length > 5 * 1024 * 1024) {
      throw StoreException('Choose an image smaller than 5 MB.');
    }
    final ext = extension.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      throw StoreException('Use a JPG, PNG, or WebP image.');
    }
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await db.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
          ),
        );
    return db.storage.from('product-images').getPublicUrl(path);
  }
}
