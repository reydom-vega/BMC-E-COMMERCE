import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/providers/auth_controller.dart';
import 'package:trendkicks/screens/orders_screen.dart';
import 'package:trendkicks/screens/order_document_screen.dart';
import 'package:trendkicks/services/order_documents.dart';
import 'package:trendkicks/services/store_backend.dart';

const id = '12345678-1234-1234-1234-123456789012';

class DocumentTransport extends http.BaseClient {
  Map<String, dynamic>? receipt;
  int writes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') writes++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(receipt == null ? [] : [receipt]))),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

class DocumentBackend extends StoreBackend {
  DocumentBackend(this.transport) : super(null);
  final DocumentTransport transport;
  String customer = 'alice';
  bool paid = false;
  final stages = <String>[];
  late final testClient = SupabaseClient(
    'https://test.supabase.co',
    'public',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  @override
  SupabaseClient get db => testClient;
  @override
  String get userId => 'alice';
  @override
  Future<StoreOrder> order(String key) async => StoreOrder({
    'id': key,
    'user_id': customer,
    'status': stages.isEmpty ? 'PENDING' : stages.last,
    'payment_status': paid ? 'PAID' : 'DUE',
    'payment_method': 'COD',
    'created_at': '2026-10-25T00:00:00Z',
    'paid_at': paid ? '2026-10-25T01:00:00Z' : null,
    'payment_reference': paid ? 'COD-$key' : null,
    'subtotal_cents': 250000,
    'shipping_cents': 10000,
    'voucher_discount_cents': 10000,
    'loyalty_discount_cents': 5000,
    'total_cents': 245000,
    'delivery': {
      'name': 'Alice Test',
      'phone': '09123456789',
      'address': '123 School Street, Manila',
    },
    'items': [
      {
        'name': 'Historical sneaker',
        'size': '8',
        'color': 'Black',
        'quantity': 1,
        'unit_price_cents': 250000,
      },
    ],
  });
  @override
  Future<List<Map<String, dynamic>>> refunds({String? orderId}) async => [];
  @override
  Future<void> advanceOrder(String id, String status) async {
    stages.add(status);
  }
}

class DocumentAuth extends AuthController {
  DocumentAuth({bool admin = false}) : super(StoreBackend(null)) {
    profile = CustomerProfile(id: 'alice', isAdmin: admin);
  }
  @override
  String get userId => 'alice';
  @override
  bool get signedIn => true;
  @override
  Future<void> refresh() async {}
}

class TestRaster extends PdfRaster {
  TestRaster() : super(10, 10, Uint8List(400));
  @override
  Future<Uint8List> toPng() async =>
      (await rootBundle.load('assets/branding/wordmark.png')).buffer
          .asUint8List();
}

class PreviewPrinter extends PrintingPlatform {
  int previews = 0, saves = 0, shares = 0;
  Uint8List? last;
  @override
  Future<PrintingInfo> info() async =>
      const PrintingInfo(canRaster: true, canPrint: true, canShare: true);
  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    previews++;
    last = document;
    yield TestRaster();
  }

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async {
    shares++;
    last = bytes;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #layoutPdf) {
      saves++;
      return Future<Uint8List>.sync(
        () => (call.positionalArguments[1] as LayoutCallback)(PdfPageFormat.a4),
      ).then((bytes) {
        last = bytes;
        return true;
      });
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DocumentTransport transport;
  late DocumentBackend backend;
  late DocumentAuth auth;
  late PreviewPrinter printer;
  late PrintingPlatform original;
  setUp(() {
    transport = DocumentTransport();
    backend = DocumentBackend(transport);
    auth = DocumentAuth();
    original = PrintingPlatform.instance;
    printer = PreviewPrinter();
    PrintingPlatform.instance = printer;
  });
  tearDown(() {
    auth.dispose();
    PrintingPlatform.instance = original;
  });
  Future<void> ready(WidgetTester tester) async {
    // PDF font/image compression runs asynchronously; give real asset I/O time.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StoreBackend>.value(value: backend),
          ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp(key: UniqueKey(), theme: buildTheme(), home: screen),
      ),
    );
    await tester.pump();
    await ready(tester);
  }

  testWidgets(
    'confirmation and paid receipt open the real viewer and save/share valid PDF bytes',
    (tester) async {
      await show(tester, const OrderDetailScreen(orderId: id));
      expect(find.text('Delivery tracking'), findsNothing);
      await tester.ensureVisible(find.text('Order confirmation'));
      await tester.tap(find.text('Order confirmation'));
      await tester.pump(const Duration(milliseconds: 250));
      await ready(tester);
      expect(find.byType(OrderDocumentScreen), findsOneWidget);
      expect(find.byType(PdfPreview), findsOneWidget);
      expect(
        find.text('Order confirmation only — not proof of payment.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(printer.saves, 1);
      expect(printer.shares, 1);
      expect(String.fromCharCodes(printer.last!.take(5)), '%PDF-');
      backend.paid = true;
      transport.receipt = {
        'reference': 'TKR-VERIFIED-SCHOOL',
        'snapshot': (await backend.order(id)).data,
      };
      await show(tester, const OrderDocumentScreen(orderId: id, paid: true));
      await ready(tester);
      expect(find.byType(PdfPreview), findsOneWidget);
      expect(
        find.text('Order confirmation only — not proof of payment.'),
        findsNothing,
      );
      expect(transport.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unpaid orders and mismatched owner/snapshot cannot create paid receipts',
    (tester) async {
      await expectLater(
        OrderDocuments.prepare(backend, id, paid: true),
        throwsA(isA<StoreException>()),
      );
      backend.customer = 'bob';
      await expectLater(
        OrderDocuments.prepare(backend, id),
        throwsA(isA<StoreException>()),
      );
      backend.customer = 'alice';
      backend.paid = true;
      transport.receipt = {
        'reference': 'TKR-WRONG',
        'snapshot': {...(await backend.order(id)).data, 'user_id': 'bob'},
      };
      await expectLater(
        OrderDocuments.prepare(backend, id, paid: true),
        throwsA(isA<StoreException>()),
      );
    },
  );
  testWidgets('admin order status actions remain without shipment management', (
    tester,
  ) async {
    auth.profile = const CustomerProfile(id: 'alice', isAdmin: true);
    await show(tester, const OrderDetailScreen(orderId: id));
    expect(find.text('Delivery tracking'), findsNothing);
    expect(find.text('Edit tracking / add delivery event'), findsNothing);
    await tester.ensureVisible(find.text('Mark Confirmed'));
    await tester.tap(find.text('Mark Confirmed'));
    await tester.pumpAndSettle();
    expect(backend.stages, ['CONFIRMED']);
    expect(find.text('Mark Preparing'), findsOneWidget);
  });
}
