import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:she_her_circle/models/order.dart' as models;

class OrderCreateRequest {
  final String sellerId;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final num price;
  final int quantity;

  OrderCreateRequest({
    required this.sellerId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.productImageUrl,
  });

  Map<String, dynamic> toMap({required String buyerId}) {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'price': price,
      'quantity': quantity,
      'status': models.OrderStatus.pending.name,
      // Use client timestamps so new orders don't disappear while waiting for server time
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };
  }
}

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> createOrders({
    required String buyerId,
    required List<OrderCreateRequest> orders,
  }) async {
    if (orders.isEmpty) return [];
    final batch = _firestore.batch();
    final ids = <String>[];
    for (final order in orders) {
      final doc = _firestore.collection('orders').doc();
      batch.set(doc, order.toMap(buyerId: buyerId));
      ids.add(doc.id);
    }
    await batch.commit();
    return ids;
  }

  Future<void> updateStatus(String orderId, models.OrderStatus status) {
    return _firestore.collection('orders').doc(orderId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Convenience: accept plain string status too
  Future<void> updateOrderStatus(String orderId, String nextStatus) {
    return _firestore.collection('orders').doc(orderId).update({
      'status': nextStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<models.Order>> streamBuyerOrders(String buyerId) {
    return _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(models.Order.fromDoc).toList());
  }

  Stream<List<models.Order>> streamSellerOrders(String sellerId) {
    return _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(models.Order.fromDoc).toList());
  }
}
