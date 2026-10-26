import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/providers/auth_controller.dart';
import 'package:trendkicks/screens/orders_screen.dart';
import 'package:trendkicks/screens/xendit_webview_screen.dart';
import 'package:trendkicks/services/store_backend.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const invoiceUrl = 'https://invoice-staging.xendit.co/web/invoices/test-order';
const orderId = '12345678-1234-1234-1234-123456789012';

Map<String, dynamic> orderData({
  String paymentStatus = 'PENDING',
  String url = invoiceUrl,
}) => {
  'id': orderId,
  'user_id': 'customer',
  'status': 'PENDING',
  'payment_status': paymentStatus,
  'payment_method': 'XENDIT',
  'invoice_url': url,
  'total_cents': 220000,
  'shipping_cents': 12000,
  'items': <Map<String, dynamic>>[],
  'delivery': {
    'name': 'Test Customer',
    'phone': '09123456789',
    'address': 'Test delivery address',
  },
  'created_at': '2026-10-23T00:00:00Z',
};

class _Launcher extends UrlLauncherPlatform {
  final calls = <(String, LaunchOptions)>[];
  bool succeeds = true;
  @override
  get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add((url, options));
    return succeeds;
  }
}

class _InvoiceFunctions extends Fake implements FunctionsClient {
  final response = Completer<FunctionResponse>();
  final requests = <Map<String, dynamic>>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #invoke) {
      expect(invocation.positionalArguments.single, 'create-invoice');
      requests.add(
        Map<String, dynamic>.from(invocation.namedArguments[#body] as Map),
      );
      return response.future;
    }
    return super.noSuchMethod(invocation);
  }
}

class _Client extends Fake implements SupabaseClient {
  _Client(this.functions);
  @override
  final FunctionsClient functions;
}

class _Backend extends StoreBackend {
  _Backend() : super(null);
  final invoices = _InvoiceFunctions();
  @override
  SupabaseClient get db => _Client(invoices);
  @override
  Future<StoreOrder> order(String id) async => StoreOrder(orderData());
  @override
  Future<List<Map<String, dynamic>>> refunds({String? orderId}) async => [];
}

class _Auth extends AuthController {
  _Auth() : super(StoreBackend(null));
  @override
  String get userId => 'customer';
  @override
  bool get signedIn => true;
  @override
  Future<void> refresh() async {}
}

void main() {
  late _Launcher launcher;
  late UrlLauncherPlatform previousLauncher;
  late _Backend backend;
  setUp(() {
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
  });
  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
  });

  Future<void> showOrder(
    WidgetTester tester, {
    bool startPayment = false,
  }) async {
    // Create the pending invoice Future inside the widget test's async zone.
    backend = _Backend();
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StoreBackend>.value(value: backend),
          ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: OrderDetailScreen(
            orderId: orderId,
            newOrder: startPayment,
            initialInvoiceUrl: startPayment ? invoiceUrl : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continuePayment(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Continue to payment');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets(
    'one click opens payment after the invoice response without an intermediate screen',
    (tester) async {
      await showOrder(tester);
      await continuePayment(tester);
      expect(launcher.calls, isEmpty);
      expect(backend.invoices.requests, [
        {'action': 'resume', 'order_id': orderId},
      ]);

      backend.invoices.response.complete(
        FunctionResponse(status: 200, data: {'order': orderData()}),
      );
      await tester.pumpAndSettle();
      expect(launcher.calls, hasLength(1));
      expect(launcher.calls.single.$1, invoiceUrl);
      expect(launcher.calls.single.$2.webOnlyWindowName, '_self');
      expect(find.byType(XenditWebViewScreen), findsNothing);
      expect(find.text('Open payment page'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'new online order opens its prepared invoice once without another click',
    (tester) async {
      await showOrder(tester, startPayment: true);
      expect(launcher.calls, hasLength(1));
      expect(launcher.calls.single.$1, invoiceUrl);
      expect(backend.invoices.requests, isEmpty);
      await tester.tap(find.byTooltip('Refresh order'));
      await tester.pumpAndSettle();
      expect(launcher.calls, hasLength(1));
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.byType(XenditWebViewScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('a failed launch keeps the order available for retry', (
    tester,
  ) async {
    launcher.succeeds = false;
    await showOrder(tester);
    backend.invoices.response.complete(
      FunctionResponse(status: 200, data: {'order': orderData()}),
    );
    await continuePayment(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn’t open checkout. Please try again from your order.'),
      findsOneWidget,
    );
    expect(find.byType(OrderDetailScreen), findsOneWidget);

    launcher.succeeds = true;
    await continuePayment(tester);
    await tester.pumpAndSettle();
    expect(launcher.calls, hasLength(2));
    expect(
      backend.invoices.requests.every(
        (request) => request['action'] == 'resume',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a now-paid order does not reopen payment', (tester) async {
    await showOrder(tester);
    backend.invoices.response.complete(
      FunctionResponse(
        status: 200,
        data: {'order': orderData(paymentStatus: 'PAID')},
      ),
    );
    await continuePayment(tester);
    await tester.pumpAndSettle();
    expect(launcher.calls, isEmpty);
    expect(find.byType(XenditWebViewScreen), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('an untrusted invoice URL is never opened', (tester) async {
    await showOrder(tester);
    backend.invoices.response.complete(
      FunctionResponse(
        status: 200,
        data: {'order': orderData(url: 'https://xendit.co.attacker.test/pay')},
      ),
    );
    await continuePayment(tester);
    await tester.pumpAndSettle();
    expect(launcher.calls, isEmpty);
    expect(
      find.text('This payment link is invalid. Please return to your order.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
