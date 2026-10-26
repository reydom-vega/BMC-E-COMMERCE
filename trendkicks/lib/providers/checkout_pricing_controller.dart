import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/ui.dart';
import '../models/commerce_models.dart';

typedef CheckoutQuote = Future<Map<String, dynamic>> Function(
  List<CartLine> lines,
  String voucher,
  int points,
);

/// Every accepted price comes from tk_quote, the same calculation used by checkout.
class CheckoutPricingController extends ChangeNotifier {
  CheckoutPricingController({
    required this.fetchQuote,
    required this.fetchRewards,
    required List<CartLine> lines,
  }) : lines = List.unmodifiable(lines);
  final CheckoutQuote fetchQuote;
  final Future<Map<String, dynamic>> Function() fetchRewards;
  List<CartLine> lines;
  Map<String, dynamic>? price, rewards;
  String voucherCode = '', appliedCode = '';
  bool rewardsEnabled = false, loading = true, rewardsLoading = true;
  int selectedPoints = 0, appliedPoints = 0;
  String? voucherError, rewardsError, pricingError, balanceError;
  Timer? _debounce;
  int _version = 0;
  bool _disposed = false;
  int get balance => (rewards?['balance'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get rules =>
      Map<String, dynamic>.from(rewards?['rules'] as Map? ?? {});
  int get step => (rules['redeem_points'] as num?)?.toInt() ?? 0;
  int get minimum => step <= 0
      ? 0
      : (((rules['minimum_points'] as num?)?.toInt() ?? step) + step - 1) ~/
            step *
            step;
  int get subtotal =>
      (price?['subtotal_cents'] as num?)?.toInt() ??
      lines.fold(0, (sum, line) => sum + line.totalCents);
  int get shipping => (price?['shipping_cents'] as num?)?.toInt() ?? 0;
  int get voucherDiscount =>
      (price?['voucher_discount_cents'] as num?)?.toInt() ?? 0;
  int get rewardsDiscount =>
      (price?['loyalty_discount_cents'] as num?)?.toInt() ?? 0;
  int get total =>
      max(0, (price?['total_cents'] as num?)?.toInt() ?? subtotal + shipping);
  int get maximumPoints {
    final value = (rules['redeem_value_cents'] as num?)?.toInt() ?? 0;
    if (step <= 0 || value <= 0 || rules['active'] != true) return 0;
    final cap = (rules['max_discount_cents'] as num?)?.toInt() ?? 0;
    return min(
          balance ~/ step,
          min(cap, max(0, subtotal - voucherDiscount)) ~/ value,
        ) *
        step;
  }

  List<int> get options {
    if (minimum <= 0 || maximumPoints < minimum) return [];
    final count = (maximumPoints - minimum) ~/ step + 1;
    // Keep an unusually large admin-configured range usable on a phone.
    return [
      for (var i = 0; i < min(49, count); i++) minimum + i * step,
      if (count > 49) maximumPoints,
    ];
  }

  String? get unavailableReason {
    if (rewardsLoading) return 'Loading your available points...';
    if (balanceError != null) return balanceError;
    if (rules['active'] != true) {
      return 'Reward redemption is currently paused.';
    }
    if (balance < minimum) {
      return 'You need at least $minimum available points to redeem rewards.';
    }
    if (maximumPoints < minimum) {
      return 'This order is below the minimum eligible rewards amount.';
    }
    return null;
  }

  bool get canSubmit =>
      price != null &&
      !loading &&
      lines.isNotEmpty &&
      pricingError == null &&
      voucherError == null &&
      (!rewardsEnabled ||
          (rewardsError == null && !rewardsLoading && balanceError == null));

  Future<void> initialize() async {
    await Future.wait([loadRewards(), refresh()]);
  }

  Future<void> loadRewards() async {
    rewardsLoading = true;
    _emit();
    try {
      final result = await fetchRewards();
      if (_disposed) return;
      rewards = result;
      balanceError = null;
    } catch (error) {
      if (_disposed) return;
      balanceError =
          'Available points could not be loaded. Retry to redeem rewards.';
    }
    if (!_disposed) {
      rewardsLoading = false;
      _emit();
    }
  }

  static String fingerprint(List<CartLine> lines) => lines
      .map((l) => '${l.variant.id}:${l.quantity}:${l.product.priceCents}')
      .join('|');
  void setLines(List<CartLine> next) {
    if (fingerprint(next) == fingerprint(lines)) return;
    lines = List.unmodifiable(next);
    price = null;
    _schedule(Duration.zero);
  }

  void setVoucher(String code) {
    code = code.trim().toUpperCase();
    if (code == voucherCode) return;
    voucherCode = code;
    voucherError = null;
    // Remove the old voucher immediately. No unverified replacement is displayed.
    _removeDiscount(voucher: true);
    appliedCode = '';
    _schedule(code.isEmpty ? Duration.zero : const Duration(milliseconds: 500));
  }

  void setRewardsEnabled(bool value) {
    if (value && unavailableReason != null) return;
    rewardsEnabled = value;
    rewardsError = null;
    if (value) {
      if (!options.contains(selectedPoints)) selectedPoints = minimum;
    } else {
      _removeDiscount(voucher: false);
      appliedPoints = 0;
    }
    _schedule(Duration.zero);
  }

  void setPoints(int points) {
    selectedPoints = points;
    rewardsError = null;
    _removeDiscount(voucher: false);
    appliedPoints = 0;
    _schedule(Duration.zero);
  }

  void _removeDiscount({required bool voucher}) {
    if (price == null) return;
    final field = voucher ? 'voucher_discount_cents' : 'loyalty_discount_cents';
    price = {
      ...price!,
      'total_cents': total + (price![field] as num).toInt(),
      field: 0,
    };
  }

  void _schedule(Duration delay) {
    _debounce?.cancel();
    final version = ++_version;
    loading = true;
    pricingError = null;
    _emit();
    if (delay == Duration.zero) {
      unawaited(_calculate(version));
    } else {
      _debounce = Timer(delay, () => _calculate(version));
    }
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    final version = ++_version;
    loading = true;
    pricingError = null;
    _emit();
    await _calculate(version);
  }

  Future<void> _calculate(int version) async {
    final items = List<CartLine>.of(lines), code = voucherCode;
    final points = rewardsEnabled ? selectedPoints : 0;
    bool current() => !_disposed && version == _version;
    if (items.isEmpty) {
      if (current()) {
        price = null;
        loading = false;
        pricingError = 'Your bag is empty.';
        _emit();
      }
      return;
    }
    try {
      // Validate vouchers independently. A rejected voucher never prevents a
      // rewards-only quote, and rewards never depend on voucher text.
      Map<String, dynamic>? voucherPrice;
      String validCode = code;
      String? codeError, pointError;
      if (code.isNotEmpty) {
        try {
          voucherPrice = await fetchQuote(items, code, 0);
        } catch (error) {
          validCode = '';
          codeError = friendlyError(error);
        }
        if (!current()) return;
      }
      Map<String, dynamic> result;
      int validPoints = points;
      if (points > 0) {
        try {
          result = await fetchQuote(items, validCode, points);
        } catch (error) {
          if (!current()) return;
          pointError = friendlyError(error);
          validPoints = 0;
          result = voucherPrice ?? await fetchQuote(items, validCode, 0);
        }
      } else {
        result = voucherPrice ?? await fetchQuote(items, validCode, 0);
      }
      if (!current()) return;
      price = result;
      appliedCode = validCode;
      appliedPoints = validPoints;
      voucherError = codeError;
      rewardsError = pointError;
      pricingError = null;
    } catch (error) {
      if (!current()) return;
      price = null;
      appliedCode = '';
      appliedPoints = 0;
      pricingError = friendlyError(error);
    } finally {
      if (current()) {
        loading = false;
        _emit();
      }
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_version;
    _debounce?.cancel();
    super.dispose();
  }
}
