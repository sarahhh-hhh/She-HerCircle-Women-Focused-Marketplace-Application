import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, accepted, paid, shipped, complete, canceled }

OrderStatus orderStatusFromString(String value) {
  return OrderStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => OrderStatus.pending,
  );
}

class Order {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final num price;
  final int quantity;
  final OrderStatus status;
  final String? paymentIntentId;
  final Map<String, dynamic>? shippingInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.status,
    this.productImageUrl,
    this.paymentIntentId,
    this.shippingInfo,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'price': price,
      'quantity': quantity,
      'status': status.name,
      'paymentIntentId': paymentIntentId,
      'shippingInfo': shippingInfo,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Order(
      id: doc.id,
      buyerId: data['buyerId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? 'Product',
      productImageUrl: data['productImageUrl'] as String?,
      price: (data['price'] as num?) ?? 0,
      quantity: (data['quantity'] as int?) ?? 1,
      status: orderStatusFromString(data['status'] as String? ?? ''),
      paymentIntentId: data['paymentIntentId'] as String?,
      shippingInfo: (data['shippingInfo'] as Map<String, dynamic>?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
