import '../models/commerce_models.dart';
import 'store_backend.dart';

extension ShoppingService on StoreBackend {
  Future<List<Map<String, dynamic>>> addresses() async => await db
      .from('tk_customer_addresses')
      .select()
      .eq('user_id', userId)
      .order('is_default', ascending: false)
      .order('created_at');
  Future<void> saveAddress(Map<String, dynamic> data, {String? id}) async =>
      await db.rpc('tk_save_address', params: {'p_data': data, 'p_id': id});
  Future<void> deleteAddress(String id) async => await db
      .from('tk_customer_addresses')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);
  Future<Map<String, dynamic>> quote(
    List<CartLine> lines,
    String code,
    int points,
  ) async => Map<String, dynamic>.from(
    await db.rpc(
      'tk_quote',
      params: {
        'p_items': lines.map((l) => l.toRequest()).toList(),
        'p_code': code,
        'p_points': points,
      },
    ),
  );
  Future<Map<String, dynamic>> rewardSummary() async {
    final balance = await db
        .from('tk_loyalty_accounts')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final rules = await db
        .from('tk_loyalty_rules')
        .select()
        .eq('id', 1)
        .single();
    return {
      'balance': balance?['balance'] ?? 0,
      'debt': balance?['debt'] ?? 0,
      'rules': rules,
    };
  }

  Future<Map<String, dynamic>> rewards() async {
    final summary = await rewardSummary();
    final rules = Map<String, dynamic>.from(summary['rules']);
    final ledger = await db
        .from('tk_loyalty_ledger')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final pending = await db
        .from('tk_orders')
        .select('subtotal_cents,voucher_discount_cents,loyalty_discount_cents')
        .eq('user_id', userId)
        .neq('status', 'CANCELLED')
        .neq('status', 'DELIVERED');
    return {
      ...summary,
      'ledger': ledger,
      'rules': rules,
      'pending': rules['active'] != true
          ? 0
          : pending.fold<int>(
              0,
              (s, o) =>
                  s +
                  ((o['subtotal_cents'] as int) -
                          (o['voucher_discount_cents'] as int) -
                          (o['loyalty_discount_cents'] as int)) ~/
                      (rules['earn_spend_cents'] as int),
            ),
    };
  }

  Future<Map<String, dynamic>?> receipt(String id) async =>
      await db.from('tk_receipts').select().eq('order_id', id).maybeSingle();
}
