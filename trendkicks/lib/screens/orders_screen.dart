import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../models/commerce_models.dart';
import '../providers/auth_controller.dart';
import '../providers/catalog_controller.dart';
import '../services/payment_service.dart';
import '../services/store_backend.dart';
import 'auth_screen.dart';
import 'review_dialog.dart';
import '../config/app_config.dart';
import 'order_document_screen.dart';
import 'xendit_webview_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthController>().signedIn) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Every pair has a story.',
        message: 'Sign in to see your orders and follow their journey.',
        action: FilledButton(
          onPressed: () => requireAccount(context),
          child: const Text('Sign in'),
        ),
      );
    }
    return AsyncContent<List<StoreOrder>>(
      load: () => context.read<StoreBackend>().orders(),
      builder: (context, orders, refresh) => RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.all(22),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your orders',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh orders',
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (orders.isEmpty)
              const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No orders yet',
                message:
                    'Your next favorite pair is waiting in the collection.',
              ),
            for (final order in orders)
              Card(
                elevation: 0,
                color: context.surfaceColor,
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(17),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: order.id),
                      ),
                    );
                    refresh();
                  },
                  title: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        order.reference,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      StatusPill(order.status),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      '${DateFormat.yMMMd().format(order.createdAt)}\n${order.items.map((item) => item['name']).join(', ')}\n${money(order.totalCents)} · ${label(order.paymentStatus)}',
                      style: const TextStyle(height: 1.7),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.newOrder = false,
    this.initialInvoiceUrl,
  });
  final String orderId;
  final bool newOrder;
  final String? initialInvoiceUrl;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  int version = 0;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final invoiceUrl = widget.initialInvoiceUrl;
    if (invoiceUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await action(() => openXenditCheckout(context, invoiceUrl));
        }
      });
    }
  }

  Future<void> action(Future<void> Function() callback) async {
    setState(() => busy = true);
    await perform(context, callback);
    if (mounted) {
      setState(() {
        busy = false;
        version++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      title: const Text('Order details'),
      actions: [
        IconButton(
          tooltip: 'Refresh order',
          onPressed: () => setState(() => version++),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: AsyncContent<(StoreOrder, List<Map<String, dynamic>>)>(
      key: ValueKey(version),
      load: () async {
        final backend = context.read<StoreBackend>();
        return (
          await backend.order(widget.orderId),
          await backend.refunds(orderId: widget.orderId),
        );
      },
      builder: (context, result, refresh) {
        final order = result.$1;
        final refunds = result.$2;
        final auth = context.watch<AuthController>();
        final admin = auth.profile?.isAdmin == true;
        if (!auth.signedIn ||
            (order.data['user_id'] != auth.userId && !admin)) {
          return const EmptyState(
            icon: Icons.lock_outline,
            title: 'Sign in to view this order',
            message: 'This order is private to its customer account.',
          );
        }
        return SingleChildScrollView(
          child: PageBody(
            maxWidth: 750,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.newOrder) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: context.inkColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order.method == 'COD'
                        ? 'Your order is placed.'
                        : 'Your order is reserved.',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.method == 'COD'
                        ? 'We’ll keep you posted on every step.'
                        : 'Complete payment below to confirm your order.',
                    style: TextStyle(color: context.mutedColor),
                  ),
                  const Divider(),
                ],
                Text(
                  order.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat.yMMMMd().add_jm().format(order.createdAt),
                  style: TextStyle(color: context.mutedColor),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatusPill(order.status),
                    StatusPill(order.paymentStatus),
                  ],
                ),
                const SizedBox(height: 24),
                if (order.status != 'CANCELLED')
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < orderStages.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              orderStages.indexOf(order.status) >= i
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: orderStages.indexOf(order.status) >= i
                                  ? context.inkColor
                                  : context.mutedColor,
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label(orderStages[i]),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                if (order.paymentStatus == 'REFUND_REQUIRED')
                  Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text(
                      'A payment was received for a cancelled order. Contact the store to arrange your refund.',
                      style: TextStyle(color: context.accentColor),
                    ),
                  ),
                if (AppConfig.advancedShopping &&
                    admin &&
                    order.method == 'XENDIT' &&
                    ['PAID', 'REFUND_REQUIRED'].contains(order.paymentStatus))
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final field = TextEditingController();
                            final refundId = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Verify provider refund'),
                                content: TextField(
                                  controller: field,
                                  decoration: const InputDecoration(
                                    labelText: 'Xendit refund ID',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, field.text.trim()),
                                    child: const Text('Verify'),
                                  ),
                                ],
                              ),
                            );
                            if (refundId != null && mounted) {
                              await action(
                                () =>
                                    PaymentService(context.read<StoreBackend>())
                                        .verifyRefund(order.id, refundId),
                              );
                            }
                          },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verify provider refund'),
                  ),
                if (order.canPay) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            final latest = await PaymentService(
                              context.read<StoreBackend>(),
                            ).resume(order.id);
                            if (!context.mounted) return;
                            if (latest.canPay && latest.invoiceUrl != null) {
                              await openXenditCheckout(
                                context,
                                latest.invoiceUrl!,
                              );
                            }
                          }),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Continue to payment'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            await PaymentService(context.read<StoreBackend>())
                                .resume(order.id);
                          }),
                    child: const Text('Check payment'),
                  ),
                  Text(
                    'Payments are confirmed by Xendit. If you’ve just paid, allow a moment and check again.',
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                ],
                const Divider(),
                if (AppConfig.advancedShopping &&
                    order.data['user_id'] == auth.userId)
                  Wrap(
                    spacing: 10,
                    children: [
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => action(() async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderDocumentScreen(orderId: order.id),
                                  ),
                                );
                              }),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Order confirmation'),
                      ),
                      if (order.paymentStatus == 'PAID')
                        TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => action(() async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderDocumentScreen(
                                        orderId: order.id,
                                        paid: true,
                                      ),
                                    ),
                                  );
                                }),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Payment receipt'),
                        ),
                    ],
                  ),
                const Text(
                  'Your pairs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 65,
                              height: 75,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ShoeImage(
                                  item['image'] as String? ?? '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'US ${item['size']} · ${item['color']}\nQty ${item['quantity']}',
                                    style: TextStyle(
                                      color: context.mutedColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money(
                                (item['unit_price_cents'] as int) *
                                    (item['quantity'] as int),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (order.status == 'DELIVERED' &&
                            order.data['user_id'] == auth.userId)
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                          showReview(
                                            context,
                                            order.id,
                                            item['item_id'] as String,
                                          ).then((_) {
                                            if (mounted) {
                                              setState(() => version++);
                                            }
                                          }),
                                child: const Text('Write / edit review'),
                              ),
                              if (!refunds.any(
                                (r) => r['item_id'] == item['item_id'],
                              ))
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            showRefund(
                                              context,
                                              order.id,
                                              item['item_id'] as String,
                                            ).then((_) {
                                              if (mounted) {
                                                setState(() => version++);
                                              }
                                            }),
                                  child: const Text('Request refund'),
                                ),
                            ],
                          ),
                        for (final refund in refunds.where(
                          (r) => r['item_id'] == item['item_id'],
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusPill(refund['status'] as String),
                                if (AppConfig.advancedShopping &&
                                    refund['processing_status'] != null &&
                                    refund['processing_status'] !=
                                        'NOT_STARTED')
                                  Text(
                                    'Refund processing: ${label(refund['processing_status'] as String)}',
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  'Refund request: ${refund['reason']}',
                                  style: TextStyle(
                                    color: context.mutedColor,
                                    fontSize: 12,
                                  ),
                                ),
                                if (refund['status'] == 'APPROVED' &&
                                    refund['processing_status'] != 'COMPLETED')
                                  Text(
                                    'Approved for processing. Approval does not mean money has been returned.',
                                    style: TextStyle(
                                      color: context.accentColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (refund['processing_status'] == 'COMPLETED')
                                  const Text(
                                    'A refund settlement has been verified for this order.',
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                Text('Delivery · ${money(order.shippingCents)}'),
                if ((order.data['voucher_discount_cents'] as int? ?? 0) > 0)
                  Text(
                    'Voucher discount · ${money(-(order.data['voucher_discount_cents'] as int))}',
                  ),
                if ((order.data['loyalty_discount_cents'] as int? ?? 0) > 0)
                  Text(
                    'Rewards discount · ${money(-(order.data['loyalty_discount_cents'] as int))}',
                  ),
                const SizedBox(height: 8),
                Text(
                  'Total · ${money(order.totalCents)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Deliver to',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${order.address['name']}\n${order.address['phone']}\n${order.address['address']}',
                  style: TextStyle(color: context.mutedColor, height: 1.6),
                ),
                const SizedBox(height: 14),
                Text(
                  'Payment · ${order.method == 'COD' ? 'Cash on delivery' : 'Xendit online payment'}',
                ),
                if (order.canCancel &&
                    order.data['user_id'] == auth.userId) ...[
                  const Divider(),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!await confirm(
                              context,
                              'Cancel this order?',
                              'Your reserved pairs will be returned to stock. Payments already received require a separate refund.',
                            )) {
                              return;
                            }
                            if (!context.mounted) return;
                            await action(
                              () =>
                                  PaymentService(context.read<StoreBackend>())
                                      .cancel(order),
                            );
                          },
                    child: const Text('Cancel order'),
                  ),
                ],
                if (admin &&
                    order.status != 'CANCELLED' &&
                    order.status != 'DELIVERED') ...[
                  const Divider(),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            final next =
                                orderStages[orderStages.indexOf(order.status) +
                                    1];
                            await context.read<StoreBackend>().advanceOrder(
                              order.id,
                              next,
                            );
                          }),
                    child: Text(
                      'Mark ${label(orderStages[orderStages.indexOf(order.status) + 1])}',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showReview(BuildContext context, String order, String item) async {
  final backend = context.read<StoreBackend>();
  final catalog = context.read<CatalogController>();
  Map<String, dynamic>? existing;
  try {
    existing = await backend.myReview(order, item);
  } catch (error) {
    if (context.mounted) toast(context, friendlyError(error));
    return;
  }
  if (!context.mounted) return;
  final owner = backend.userId;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReviewDialog(
      backend: backend,
      orderId: order,
      itemId: item,
      owner: owner,
      existing: existing,
    ),
  );
  if (saved == true) {
    await catalog.load();
    if (context.mounted) toast(context, 'Review saved.');
  }
}

Future<void> showRefund(BuildContext context, String order, String item) async {
  final backend = context.read<StoreBackend>();
  String reason = refundReasons.first;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Request an item refund'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                isExpanded: true,
                items: refundReasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: busy ? null : (r) => reason = r!,
              ),
              const SizedBox(height: 16),
              const Text(
                'The store will review your request. Approval and the return of funds are separate steps.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await backend.requestRefund(order, item, reason);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      if (dialogContext.mounted) {
                        toast(dialogContext, friendlyError(e));
                        setState(() => busy = false);
                      }
                    }
                  },
            child: Text(busy ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    ),
  );
}
