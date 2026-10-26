import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../models/commerce_models.dart';
import '../providers/auth_controller.dart';
import '../providers/cart_controller.dart';
import '../providers/checkout_pricing_controller.dart';
import '../services/payment_service.dart';
import '../services/store_backend.dart';
import 'orders_screen.dart';
import 'address_book_screen.dart';
import 'rewards_screen.dart';
import '../services/shopping_service.dart';
import '../config/app_config.dart';
import 'checkout_discounts.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.lines});
  final List<CartLine> lines;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver {
  final voucher = TextEditingController();
  late final CheckoutPricingController pricing;
  CartController? cartSource;
  Timer? refreshTimer;
  Map<String, dynamic>? get quote =>
      AppConfig.advancedShopping ? pricing.price : null;
  List<CartLine> get lines =>
      AppConfig.advancedShopping ? pricing.lines : widget.lines;
  String? addressId;
  final form = GlobalKey<FormState>();
  late final TextEditingController name, phone, address;
  late Future<int> fee;
  final requestKey = newRequestKey();
  String method = 'COD';
  String? error;
  bool busy = false, attempted = false;
  String? checkoutOwner;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final backend = context.read<StoreBackend>();
    checkoutOwner = context.read<AuthController>().userId;
    pricing = CheckoutPricingController(
      fetchQuote: backend.quote,
      fetchRewards: backend.rewardSummary,
      lines: widget.lines,
    )..addListener(_pricingChanged);
    if (AppConfig.advancedShopping) {
      unawaited(pricing.initialize());
      cartSource = context.read<CartController?>();
      cartSource?.addListener(_cartChanged);
      refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!attempted && !busy && !pricing.loading) {
          unawaited(pricing.refresh());
        }
      });
    }
    final profile = context.read<AuthController>().profile;
    name = TextEditingController(text: profile?.name);
    phone = TextEditingController(text: profile?.phone);
    address = TextEditingController(text: profile?.address);
    fee = context.read<StoreBackend>().shippingFee();
    if (AppConfig.advancedShopping) {
      context
          .read<StoreBackend>()
          .addresses()
          .then((rows) {
            final saved = rows
                .where((r) => r['is_default'] == true)
                .firstOrNull;
            if (saved != null &&
                mounted &&
                !attempted &&
                name.text == (profile?.name ?? '')) {
              setState(() {
                addressId = saved['id'];
                name.text = saved['recipient'];
                phone.text = saved['mobile'];
                address.text =
                    '${saved['street']}, ${saved['barangay']}, ${saved['city']}, ${saved['province']} ${saved['postal_code']}';
              });
            }
          })
          .catchError((_) {
            /* Keep the profile delivery fallback. Address Book exposes retry. */
          });
    }
  }

  void _pricingChanged() {
    if (mounted) setState(() {});
  }

  void _cartChanged() {
    if (!attempted && !busy && cartSource?.busy == false) {
      pricing.setLines(cartSource!.lines);
    }
  }

  @override
  void didUpdateWidget(covariant CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!attempted && AppConfig.advancedShopping) {
      pricing.setLines(widget.lines);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !attempted &&
        AppConfig.advancedShopping) {
      unawaited(pricing.loadRewards());
      unawaited(pricing.refresh());
    }
  }

  @override
  void dispose() {
    voucher.dispose();
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    cartSource?.removeListener(_cartChanged);
    pricing.dispose();
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final backend = context.read<StoreBackend>();
      if (backend.userId != checkoutOwner) {
        throw StoreException(
          'Your account changed. Open checkout again from your bag.',
        );
      }
      final cart = context.read<CartController>();
      if (AppConfig.advancedShopping && !attempted) {
        final previousTotal = pricing.total;
        await pricing.refresh();
        if (!pricing.canSubmit) {
          throw StoreException(
            'Review the voucher, rewards and updated order total before continuing.',
          );
        }
        if (previousTotal != pricing.total) {
          throw StoreException(
            'Your order total changed. Review the updated summary and continue.',
          );
        }
      }
      if (!mounted) return;
      setState(() => attempted = true);
      final order = await PaymentService(backend).checkout(
        lines: lines,
        delivery: {
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'address': address.text.trim(),
        },
        method: method,
        requestKey: requestKey,
        voucherCode: AppConfig.advancedShopping ? pricing.appliedCode : '',
        points: AppConfig.advancedShopping ? pricing.appliedPoints : 0,
        addressId: addressId,
        expectedTotalCents:
            quote?['total_cents'] as int? ??
            lines.fold(0, (sum, line) => sum + line.totalCents) + await fee,
      );
      await cart.refresh();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            orderId: order.id,
            newOrder: true,
            initialInvoiceUrl: order.canPay ? order.invoiceUrl : null,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              '${friendlyError(e)}${attempted ? ' You can retry this same order or check your order history.' : ''}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      context.watch<AuthController>().userId != checkoutOwner
      ? Scaffold(
          appBar: BrandAppBar(title: const Text('Checkout')),
          body: const EmptyState(
            icon: Icons.lock_outline,
            title: 'Your account changed',
            message: 'Return to your bag and open checkout again.',
          ),
        )
      : Scaffold(
          appBar: BrandAppBar(title: const Text('Checkout')),
          body: FutureBuilder<int>(
            future: fee,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.wifi_off,
                  title: 'Checkout unavailable',
                  message: 'We couldn’t calculate shipping. Please try again.',
                  action: OutlinedButton(
                    onPressed: () => setState(
                      () => fee = context.read<StoreBackend>().shippingFee(),
                    ),
                    child: const Text('Retry'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final subtotal = lines.fold(
                0,
                (sum, line) => sum + line.totalCents,
              );
              return SingleChildScrollView(
                child: PageBody(
                  maxWidth: 650,
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Almost yours.',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review your pairs and delivery details.',
                          style: TextStyle(color: context.mutedColor),
                        ),
                        const SizedBox(height: 24),
                        for (final line in lines)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(
                              width: 52,
                              height: 60,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ShoeImage(line.product.imageUrl),
                              ),
                            ),
                            title: Text(line.product.name),
                            subtitle: Text(
                              'US ${line.variant.size} · ${line.variant.color} · Qty ${line.quantity}',
                            ),
                            trailing: Text(money(line.totalCents)),
                          ),
                        const Divider(),
                        const Text(
                          'Deliver to',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (AppConfig.advancedShopping)
                          TextButton.icon(
                            onPressed: attempted
                                ? null
                                : () async {
                                    final row =
                                        await Navigator.push<
                                          Map<String, dynamic>
                                        >(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AddressBookScreen(
                                                  select: true,
                                                ),
                                          ),
                                        );
                                    if (row != null && mounted) {
                                      setState(() {
                                        addressId = row['id'];
                                        name.text = row['recipient'];
                                        phone.text = row['mobile'];
                                        address.text =
                                            '${row['street']}, ${row['barangay']}, ${row['city']}, ${row['province']} ${row['postal_code']}';
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.location_on_outlined),
                            label: const Text('Choose / add saved address'),
                          ),
                        for (final entry in [
                          (name, 'Full name'),
                          (phone, 'Phone number'),
                          (address, 'Complete delivery address'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: entry.$1,
                              readOnly: attempted || addressId != null,
                              maxLength: entry.$1 == address ? 600 : 120,
                              maxLines: entry.$1 == address ? 3 : 1,
                              keyboardType: entry.$1 == phone
                                  ? TextInputType.phone
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: entry.$2,
                                counterText: '',
                              ),
                              validator: (v) =>
                                  (v?.trim().length ?? 0) <
                                      (entry.$1 == address ? 10 : 2)
                                  ? 'Please enter your ${entry.$2.toLowerCase()}.'
                                  : null,
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Payment method',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final option in [
                          (
                            'COD',
                            'Cash on delivery',
                            'Pay when your order arrives.',
                            Icons.payments_outlined,
                          ),
                          (
                            'XENDIT',
                            'Online payment',
                            'GCash / Maya via Xendit, subject to store availability.',
                            Icons.account_balance_wallet_outlined,
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: method == option.$1
                                      ? context.inkColor
                                      : context.borderColor,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                onTap: attempted
                                    ? null
                                    : () => setState(() => method = option.$1),
                                leading: Icon(option.$4),
                                title: Text(
                                  option.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(option.$3),
                                trailing: Icon(
                                  method == option.$1
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                ),
                              ),
                            ),
                          ),
                        const Divider(),
                        if (AppConfig.advancedShopping)
                          CheckoutDiscounts(
                            pricing: pricing,
                            voucher: voucher,
                            locked: attempted || busy,
                          ),
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _total(
                          'Subtotal',
                          quote?['subtotal_cents'] as int? ?? subtotal,
                        ),
                        if (quote != null) ...[
                          if (pricing.appliedCode.isNotEmpty)
                            Text('Applied voucher: ${pricing.appliedCode}'),
                          _total(
                            'Voucher discount',
                            -(quote!['voucher_discount_cents'] as int),
                          ),
                          _total(
                            'Rewards discount',
                            -(quote!['loyalty_discount_cents'] as int),
                          ),
                        ],
                        if (AppConfig.advancedShopping)
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RewardsScreen(),
                              ),
                            ),
                            child: const Text('View my rewards'),
                          ),
                        _total(
                          'Shipping Fee',
                          quote?['shipping_cents'] as int? ?? snapshot.data!,
                        ),
                        const SizedBox(height: 8),
                        _total(
                          'Total Payment',
                          quote?['total_cents'] as int? ??
                              subtotal + snapshot.data!,
                          bold: true,
                        ),
                        if (AppConfig.advancedShopping) ...[
                          if (pricing.loading) const LinearProgressIndicator(),
                          if (pricing.loading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Updating your total...'),
                            ),
                          if (pricing.pricingError != null)
                            Text(
                              pricing.pricingError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          TextButton.icon(
                            onPressed: attempted || busy || pricing.loading
                                ? null
                                : () async {
                                    await pricing.loadRewards();
                                    await pricing.refresh();
                                  },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh totals'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Availability and totals are verified by the store when your order is placed.',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              error!,
                              style: TextStyle(color: context.accentColor),
                            ),
                          ),
                        if (error != null)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    setState(() => busy = true);
                                    await perform(context, () async {
                                      final existing = await context
                                          .read<StoreBackend>()
                                          .db
                                          .from('tk_orders')
                                          .select()
                                          .eq(
                                            'user_id',
                                            context.read<StoreBackend>().userId,
                                          )
                                          .eq('request_key', requestKey)
                                          .maybeSingle();
                                      if (!context.mounted) return;
                                      if (existing != null) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OrderDetailScreen(
                                              orderId: existing['id'],
                                            ),
                                          ),
                                        );
                                      } else {
                                        setState(() {
                                          attempted = false;
                                          error = null;
                                          unawaited(pricing.loadRewards());
                                          unawaited(pricing.refresh());
                                          addressId = null;
                                          fee = context
                                              .read<StoreBackend>()
                                              .shippingFee();
                                        });
                                      }
                                    });
                                    if (mounted) setState(() => busy = false);
                                  },
                            child: const Text(
                              'Review checkout / find reserved order',
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed:
                              busy ||
                                  (AppConfig.advancedShopping &&
                                      !pricing.canSubmit)
                              ? null
                              : submit,
                          child: Text(
                            busy
                                ? 'Placing your order…'
                                : attempted
                                ? 'Retry this order'
                                : method == 'COD'
                                ? 'Place order · ${money(quote?['total_cents'] as int? ?? subtotal + snapshot.data!)}'
                                : 'Create order & continue to payment',
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
  Widget _total(String name, int value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: bold ? 20 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          money(value),
          style: TextStyle(
            fontSize: bold ? 24 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
