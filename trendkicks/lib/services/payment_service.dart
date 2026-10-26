import 'dart:convert';
import 'dart:math';

import '../config/app_config.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui.dart';
import '../models/commerce_models.dart';
import 'store_backend.dart';

String newRequestKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class PaymentService {
  PaymentService(this.backend);
  final StoreBackend backend;
  Future<StoreOrder> checkout({
    required List<CartLine> lines,
    required Map<String, dynamic> delivery,
    required String method,
    required String requestKey,
    required int expectedTotalCents,
    String voucherCode = '',
    int points = 0,
    String? addressId,
  }) async {
    final items = lines.map((line) => line.toRequest()).toList();
    if (method == 'COD') {
      final id = await backend.db.rpc(
        AppConfig.advancedShopping ? 'tk_checkout_v2' : 'tk_create_order',
        params: {
          'p_items': items,
          'p_delivery': delivery,
          'p_method': 'COD',
          'p_request_key': requestKey,
          'p_expected_total_cents': expectedTotalCents,
          if (AppConfig.advancedShopping) ...{
            'p_code': voucherCode,
            'p_points': points,
            'p_address': addressId,
          },
        },
      ) as String;
      return backend.order(id);
    }
    return _invoke({
      'action': 'create',
      'items': items,
      'delivery': delivery,
      'request_key': requestKey,
      'expected_total_cents': expectedTotalCents,
      'advanced': AppConfig.advancedShopping,
      'voucher_code': voucherCode,
      'points': points,
      'address_id': addressId,
    });
  }

  Future<StoreOrder> resume(String id) =>
      _invoke({'action': 'resume', 'order_id': id});
  Future<void> verifyRefund(String orderId, String refundId) async {
    await _invoke({
      'action': 'refund',
      'order_id': orderId,
      'refund_id': refundId,
    });
  }

  Future<void> cancel(StoreOrder order) async {
    if (order.method == 'XENDIT') {
      await _invoke({'action': 'cancel', 'order_id': order.id});
    } else {
      await backend.db.rpc('tk_cancel_order', params: {'p_order': order.id});
    }
  }

  Future<StoreOrder> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await backend.db.functions.invoke(
        'create-invoice',
        body: body,
      );
      final data = Map<String, dynamic>.from(response.data);
      if (response.status >= 400 || data['error'] != null) {
        throw StoreException(
          data['error'] as String? ?? 'Checkout is unavailable. Try again.',
        );
      }
      return StoreOrder(Map<String, dynamic>.from(data['order']));
    } on FunctionException catch (error) {
      dynamic details = error.details;
      if (details is String) {
        try {
          details = jsonDecode(details);
        } catch (_) {
          /* use safe fallback below */
        }
      }
      throw StoreException(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'Checkout is unavailable. Your order history shows any order already created.',
      );
    }
  }
}
