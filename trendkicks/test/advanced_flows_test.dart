import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/config/app_config.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/data/preview_catalog.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/providers/auth_controller.dart';
import 'package:trendkicks/screens/address_book_screen.dart';
import 'package:trendkicks/screens/checkout_screen.dart';
import 'package:trendkicks/screens/notification_preferences_screen.dart';
import 'package:trendkicks/screens/restock_screen.dart';
import 'package:trendkicks/screens/rewards_screen.dart';
import 'package:trendkicks/screens/support_screen.dart';
import 'package:trendkicks/screens/orders_screen.dart';
import 'package:trendkicks/screens/sales_report_screen.dart';
import 'package:trendkicks/services/store_backend.dart';

const _id = '12345678-1234-1234-1234-123456789012';

class _Transport extends http.BaseClient {
  final addresses = <Map<String, dynamic>>[];
  final requests = <String>[];
  final payloads = <dynamic>[];
  final messages = <Map<String, dynamic>>[];
  Map<String, dynamic>? ticket;
  Map<String, dynamic> prefs = {
    'user_id': 'alice',
    'push_enabled': false,
    'order_updates': true,
    'restock': true,
    'rewards': true,
    'support': true,
    'promotions': false,
  };
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final raw = await request.finalize().bytesToString();
    final body = raw.isEmpty ? null : jsonDecode(raw);
    final path = request.url.path;
    requests.add(path);
    payloads.add(body);
    dynamic data;
    var status = 200;
    if (path.endsWith('/rpc/tk_sales_report')) {
      data = {
        'start': body['p_start'],
        'end': body['p_end'],
        'gross_cents': 561500,
        'voucher_cents': 54950,
        'loyalty_cents': 5000,
        'collected_cents': 501550,
        'refund_cents': 0,
        'net_cents': 501550,
        'average_cents': 501550,
        'orders': 2,
        'paid_orders': 1,
        'pending_orders': 1,
        'cancelled_orders': 0,
        'voucher_uses': 1,
        'redeemed_points': 100,
        'legacy_payment_dates': 0,
        'today_cents': 501550,
        'week_cents': 501550,
        'month_cents': 501550,
        'all_time_cents': 501550,
        'low_stock': 1,
        'out_of_stock': 2,
        'daily': [
          {'sale_day': '2026-10-24', 'cents': 501550},
        ],
        'monthly': [
          {'sale_month': '2026-10', 'cents': 501550},
        ],
        'products': [
          {'name': 'Historical sneaker', 'quantity': 1, 'gross_cents': 549500},
        ],
        'statuses': [
          {'status': 'PENDING', 'count': 1},
        ],
        'methods': [
          {'payment_method': 'XENDIT', 'cents': 501550},
        ],
      };
    } else if (path.endsWith('/rpc/tk_quote')) {
      if (body['p_code'] == 'EXPIRED') {
        status = 400;
        data = {'code': 'P0001', 'message': 'This voucher has expired.'};
      } else {
        final discount = body['p_code'] == '' ? 0 : 54950;
        final rewards = (body['p_points'] as int) ~/ 100 * 5000;
        data = {
          'subtotal_cents': 549500,
          'shipping_cents': 12000,
          'voucher_discount_cents': discount,
          'loyalty_discount_cents': rewards,
          'total_cents': 561500 - discount - rewards,
        };
      }
    } else if (path.endsWith('/rpc/tk_save_address')) {
      final row = Map<String, dynamic>.from(body['p_data']);
      row['id'] = body['p_id'] ?? _id;
      row['created_at'] = '2026-10-24';
      addresses.removeWhere((r) => r['id'] == row['id']);
      addresses.add(row);
      data = row['id'];
    } else if (path.endsWith('/tk_customer_addresses')) {
      if (request.method == 'DELETE') {
        addresses.clear();
        data = [];
      } else {
        data = addresses;
      }
    } else if (path.endsWith('/tk_loyalty_accounts')) {
      data = [
        {'balance': 120, 'debt': 0},
      ];
    } else if (path.endsWith('/tk_loyalty_rules')) {
      data = {
        'id': 1,
        'active': true,
        'earn_spend_cents': 10000,
        'redeem_points': 100,
        'redeem_value_cents': 5000,
        'minimum_points': 100,
        'max_discount_cents': 50000,
      };
    } else if (path.endsWith('/tk_loyalty_ledger')) {
      data = [
        {
          'kind': 'EARN',
          'points': 120,
          'order_id': _id,
          'created_at': '2026-10-24',
        },
      ];
    } else if (path.endsWith('/tk_orders')) {
      data = [];
    } else if (path.endsWith('/rpc/tk_create_ticket')) {
      ticket = {
        'id': _id,
        'number': 12,
        'subject': body['p_subject'],
        'category': body['p_category'],
        'status': 'OPEN',
        'order_id': body['p_order'],
      };
      messages.add({
        'message': body['p_message'],
        'staff': false,
        'created_at': '2026-10-24',
      });
      data = _id;
    } else if (path.endsWith('/tk_support_tickets')) {
      data = request.headers['Accept']?.contains('object') == true
          ? ticket
          : [if (ticket != null) ticket];
    } else if (path.endsWith('/tk_support_messages')) {
      data = messages;
    } else if (path.endsWith('/rpc/tk_reply_ticket')) {
      messages.add({
        'message': body['p_message'],
        'staff': false,
        'created_at': '2026-10-24',
      });
      data = null;
    } else if (path.endsWith('/tk_shipments')) {
      data = [
        {
          'courier': 'Test courier',
          'tracking_number': 'TRACK123',
          'tracking_url': '',
        },
      ];
    } else if (path.endsWith('/tk_tracking_events')) {
      data = [
        {
          'status': 'SHIPPED',
          'message': 'Handed to courier',
          'created_at': '2026-10-24',
        },
      ];
    } else if (path.endsWith('/tk_notification_preferences')) {
      if (request.method == 'POST') {
        prefs = {...prefs, ...Map<String, dynamic>.from(body)};
        data = [prefs];
      } else {
        data = [prefs];
      }
    } else if (path.endsWith('/rpc/tk_subscribe_restock')) {
      data = null;
    } else {
      data = [];
    }
    // PostgREST single() uses a JSON object, maybeSingle() accepts a list.
    final accept = request.headers.entries
        .where((e) => e.key.toLowerCase() == 'accept')
        .map((e) => e.value)
        .join();
    if (accept.contains('vnd.pgrst.object') &&
        data is List &&
        data.length == 1) {
      data = data.first;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _Backend extends StoreBackend {
  _Backend(this.transport) : super(null);
  final _Transport transport;
  late final instance = SupabaseClient(
    'https://test.supabase.co',
    'public',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  @override
  SupabaseClient get db => instance;
  @override
  String get userId => 'alice';
  @override
  Future<int> shippingFee() async => 12000;
  bool paid = false;
  @override
  Future<StoreOrder> order(String id) async => StoreOrder({
    'id': id,
    'user_id': 'alice',
    'status': 'PENDING',
    'payment_status': paid ? 'PAID' : 'DUE',
    'payment_method': 'COD',
    'total_cents': 561500,
    'subtotal_cents': 549500,
    'shipping_cents': 12000,
    'items': <Map<String, dynamic>>[],
    'delivery': {
      'name': 'Alice',
      'phone': '09123456789',
      'address': '123 Example Street Manila',
    },
    'created_at': '2026-10-24T00:00:00Z',
    if (paid) 'paid_at': '2026-10-24T00:10:00Z',
  });
  @override
  Future<List<Map<String, dynamic>>> refunds({String? orderId}) async => [];
}

class _Auth extends AuthController {
  _Auth() : super(StoreBackend(null)) {
    profile = const CustomerProfile(
      id: 'alice',
      firstName: 'Alice',
      lastName: 'Test',
      phone: '09123456789',
      address: '123 Sample Street Manila',
    );
  }
  @override
  String get userId => 'alice';
  @override
  bool get signedIn => true;
  @override
  Future<void> refresh() async {}
}

void main() {
  final captureKey = GlobalKey();
  late _Transport transport;
  late _Backend backend;
  late _Auth auth;
  setUp(() {
    transport = _Transport();
    backend = _Backend(transport);
    auth = _Auth();
  });
  tearDown(() => auth.dispose());
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MultiProvider(
          providers: [
            Provider<StoreBackend>.value(value: backend),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    await tester.pumpAndSettle();
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/previews/advanced-$name-390.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'voucher entry displays server discounts, removal and expiry error',
    (tester) async {
      await show(
        tester,
        CheckoutScreen(
          lines: [
            CartLine(
              product: previewCatalog.first,
              variant: previewCatalog.first.variants.first,
              quantity: 1,
            ),
          ],
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Voucher code'),
        'SAVE',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(SwitchListTile, 'Use reward points'),
      );
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Use reward points'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apply voucher / rewards'), findsNothing);
      expect(find.text('Voucher discount'), findsOneWidget);
      expect(find.text(money(501550)), findsOneWidget);
      await tester.ensureVisible(find.text('Total Payment'));
      await capture(tester, 'checkout');
      await tester.ensureVisible(find.byTooltip('Clear voucher'));
      await tester.tap(find.byTooltip('Clear voucher'));
      await tester.pumpAndSettle();
      expect(find.text(money(556500)), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Voucher code'),
        'EXPIRED',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('This voucher has expired.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.advancedShopping,
  );
  testWidgets(
    'address creation, editing, default and deletion persist through service calls',
    (tester) async {
      await show(tester, const AddressBookScreen());
      await tap(tester, 'Add address');
      final values = [
        'Alice Test',
        '09123456789',
        '123 Example Street',
        'Barangay One',
        'Manila',
        'Metro Manila',
        '1000',
        'Leave with recipient',
      ];
      for (var i = 0; i < values.length; i++) {
        final field = find.byType(TextFormField).at(i);
        await tester.ensureVisible(field);
        await tester.enterText(field, values[i]);
      }
      await tap(tester, 'Save address');
      expect(transport.addresses.single['city'], 'Manila');
      await tap(tester, 'Set default');
      expect(transport.addresses.single['is_default'], true);
      await capture(tester, 'addresses');
      await tap(tester, 'Edit');
      final recipient = find.byType(TextFormField).at(0);
      await tester.ensureVisible(recipient);
      await tester.enterText(recipient, 'Alice Updated');
      await tap(tester, 'Save address');
      expect(transport.addresses.single['recipient'], 'Alice Updated');
      await tap(tester, 'Delete');
      expect(transport.addresses, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'restock subscribe reaches exact variant RPC and confirms success',
    (tester) async {
      await show(tester, const Scaffold(body: RestockButton(variantId: _id)));
      await tap(tester, 'Notify Me When Available');
      expect(transport.requests, contains('/rest/v1/rpc/tk_subscribe_restock'));
      expect(find.text('Cancel restock alert'), findsOneWidget);
      await tap(tester, 'Cancel restock alert');
      expect((transport.payloads.last as Map)['p_active'], false);
      expect(
        find.text("We'll notify you when this size becomes available."),
        findsOneWidget,
      );
    },
  );
  testWidgets('rewards cards show loaded balances and rules in dark mode', (
    tester,
  ) async {
    await show(tester, const RewardsScreen(), dark: true);
    expect(find.text('AVAILABLE POINTS'), findsOneWidget);
    expect(find.text('Redeem Rewards'), findsOneWidget);
    expect(find.textContaining('redeemable discount'), findsOneWidget);
    await capture(tester, 'rewards-dark');
    expect(tester.takeException(), isNull);
  });
  testWidgets('support creation opens saved conversation and sends a reply', (
    tester,
  ) async {
    await show(tester, const CreateTicketScreen());
    await tester.enterText(
      find.widgetWithText(TextField, 'Subject'),
      'Delivery question',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Describe your concern'),
      'Please help with tracking.',
    );
    await tap(tester, 'Send ticket');
    expect(find.textContaining('Delivery question'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Your reply'),
      'Thank you.',
    );
    await tap(tester, 'Send reply');
    expect(transport.messages.last['message'], 'Thank you.');
    await capture(tester, 'support');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'promotions default off and preference changes persist without push configuration',
    (tester) async {
      await show(tester, const NotificationPreferencesScreen());
      expect(transport.prefs['promotions'], false);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Voucher promotions (opt in)'),
      );
      await tester.pumpAndSettle();
      expect(transport.prefs['promotions'], true);
      await capture(tester, 'notification-preferences');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unpaid confirmation and verified receipt actions are separate', (
    tester,
  ) async {
    await show(tester, OrderDetailScreen(key: UniqueKey(), orderId: _id));
    expect(find.text('Order confirmation'), findsOneWidget);
    expect(find.text('Delivery tracking'), findsNothing);
    expect(
      transport.requests.where(
        (p) => p.contains('tk_shipments') || p.contains('tk_tracking_events'),
      ),
      isEmpty,
    );
    expect(find.text('Payment receipt'), findsNothing);
    backend.paid = true;
    await show(tester, OrderDetailScreen(key: UniqueKey(), orderId: _id));
    expect(find.text('Payment receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !AppConfig.advancedShopping);
  testWidgets(
    'admin report filters request aggregate dates without fetching all orders',
    (tester) async {
      await show(tester, const SalesReportScreen());
      expect(find.text('Collected payments'), findsOneWidget);
      await capture(tester, 'analytics');
      await tester.tap(find.text('Last 30 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 7 days').last);
      await tester.pumpAndSettle();
      final payload = transport.payloads.last as Map;
      expect(
        payload['p_start'],
        reportRange('Last 7 days').$1.toIso8601String().substring(0, 10),
      );
      expect(
        transport.requests.where((p) => p.endsWith('/tk_orders')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
