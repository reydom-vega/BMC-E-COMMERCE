import 'product_model.dart';

class CartLine {
  const CartLine({
    required this.product,
    required this.variant,
    required this.quantity,
  });
  final Product product;
  final ShoeVariant variant;
  final int quantity;
  int get totalCents => product.priceCents * quantity;
  Map<String, dynamic> toRequest() => {
    'variant_id': variant.id,
    'quantity': quantity,
  };
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.address = '',
    this.isAdmin = false,
  });
  final String id, firstName, lastName, phone, address;
  final bool isAdmin;
  String get name => '$firstName $lastName'.trim();
  factory CustomerProfile.fromMap(
    Map<String, dynamic> map, {
    bool isAdmin = false,
  }) => CustomerProfile(
    id: map['id'] as String,
    firstName: map['first_name'] as String? ?? '',
    lastName: map['last_name'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    address: map['address'] as String? ?? '',
    isAdmin: isAdmin,
  );
}

class StoreOrder {
  StoreOrder(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get reference => 'TK-${id.substring(0, 8).toUpperCase()}';
  String get status => data['status'] as String;
  String get paymentStatus => data['payment_status'] as String;
  String get method => data['payment_method'] as String;
  int get totalCents => (data['total_cents'] as num).toInt();
  int get shippingCents => (data['shipping_cents'] as num).toInt();
  List<Map<String, dynamic>> get items =>
      List<Map<String, dynamic>>.from(data['items']);
  Map<String, dynamic> get address =>
      Map<String, dynamic>.from(data['delivery']);
  DateTime get createdAt =>
      DateTime.parse(data['created_at'] as String).toLocal();
  String? get invoiceUrl => data['invoice_url'] as String?;
  bool get canCancel => ['PENDING', 'CONFIRMED', 'PREPARING'].contains(status);
  bool get canPay =>
      method == 'XENDIT' && paymentStatus == 'PENDING' && status != 'CANCELLED';
}

const orderStages = [
  'PENDING',
  'CONFIRMED',
  'PREPARING',
  'SHIPPED',
  'DELIVERED',
];
const refundReasons = [
  'Product arrived damaged',
  'Wrong product received',
  'Wrong size received',
  'Product does not match the order',
  'Defective product',
  'Other eligible reason',
];
