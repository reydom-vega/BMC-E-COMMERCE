import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/ui.dart';
import '../models/commerce_models.dart';
import 'store_backend.dart';
import 'shopping_service.dart';
import 'payment_service.dart';

class PreparedOrderDocument {
  const PreparedOrderDocument({
    required this.bytes,
    required this.filename,
    required this.owner,
  });
  final Uint8List bytes;
  final String filename, owner;
}

class OrderDocuments {
  static Future<Uint8List> generate(
    StoreOrder order, {
    Map<String, dynamic>? receipt,
  }) async {
    final paid = receipt != null;
    if (paid) {
      final snapshot = receipt['snapshot'];
      if (snapshot is! Map ||
          snapshot['id'] != order.id ||
          snapshot['user_id'] != order.data['user_id'] ||
          snapshot['payment_status'] != 'PAID' ||
          snapshot['paid_at'] == null ||
          receipt['reference'] is! String) {
        throw StoreException(
          'A verified payment receipt is not available for this order.',
        );
      }
    }
    final data = paid
        ? StoreOrder(Map<String, dynamic>.from(receipt['snapshot']))
        : order;
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope.ttf'));
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/branding/wordmark.png')).buffer
          .asUint8List(),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Image(logo, height: 55),
          pw.SizedBox(height: 20),
          pw.Text(
            paid ? 'Payment receipt' : 'Order confirmation',
            style: pw.TextStyle(fontSize: 24),
          ),
          if (!paid) pw.Text('Order confirmation only — not proof of payment.'),
          pw.Text('Order: ${data.reference}'),
          if (paid) pw.Text('Receipt: ${receipt['reference']}'),
          pw.Text('Placed: ${data.data['created_at']}'),
          if (paid) pw.Text('Payment verified: ${data.data['paid_at']}'),
          pw.Text('Customer: ${data.address['name']}'),
          pw.Text('${data.address['phone']}\n${data.address['address']}'),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: ['Pair / size / color', 'Qty', 'Unit (PHP)', 'Line (PHP)'],
            data: [
              for (final i in data.items)
                [
                  '${i['name']}\nUS ${i['size']} / ${i['color']}',
                  i['quantity'],
                  '${(i['unit_price_cents'] / 100).toStringAsFixed(2)}',
                  '${(i['unit_price_cents'] * i['quantity'] / 100).toStringAsFixed(2)}',
                ],
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          for (final e in {
            'Subtotal': data.data['subtotal_cents'],
            'Voucher discount':
                -(data.data['voucher_discount_cents'] as int? ?? 0),
            'Rewards discount':
                -(data.data['loyalty_discount_cents'] as int? ?? 0),
            'Shipping': data.shippingCents,
            'Total': data.totalCents,
          }.entries)
            pw.Text('${e.key}: PHP ${(e.value / 100).toStringAsFixed(2)}'),
          pw.SizedBox(height: 12),
          pw.Text('Method: ${data.method} · Status: ${data.paymentStatus}'),
          if (paid)
            pw.Text('Verified reference: ${data.data['payment_reference']}'),
        ],
      ),
    );
    return doc.save();
  }

  static Future<PreparedOrderDocument> prepare(
    StoreBackend backend,
    String orderId, {
    bool paid = false,
  }) async {
    final owner = backend.userId;
    var order = await backend.order(orderId);
    if (order.data['user_id'] != owner || backend.userId != owner) {
      throw StoreException('This document belongs to a different account.');
    }
    if (paid && order.paymentStatus != 'PAID') {
      throw StoreException(
        'Payment has not been confirmed. Open the order confirmation instead.',
      );
    }
    var receipt = paid ? await backend.receipt(order.id) : null;
    if (paid && receipt == null && order.method == 'XENDIT') {
      // Historical invoices are rechecked with Xendit before creating a receipt.
      order = await PaymentService(backend).resume(order.id);
      receipt = await backend.receipt(order.id);
    }
    if (paid && receipt == null) {
      throw StoreException(
        'A verified payment receipt is not available for this order.',
      );
    }
    final bytes = await generate(order, receipt: receipt);
    if (backend.userId != owner) {
      throw StoreException('Your account changed. Open this document again.');
    }
    return PreparedOrderDocument(
      bytes: bytes,
      filename: '${order.reference}-${paid ? 'receipt' : 'confirmation'}.pdf',
      owner: owner,
    );
  }
}
