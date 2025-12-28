import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:she_her_circle/models/product.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all products from Firestore
  Future<List<Product>> getAllProducts() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      return snapshot.docs.map((doc) {
        return _productFromDoc(doc);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch products: $e';
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) {
        return _productFromDoc(doc);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch products: $e';
    }
  }

  /// Get auction products
  Future<List<Product>> getAuctionProducts() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isAuctionEnabled', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) {
        return _productFromDoc(doc);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch auction products: $e';
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return _productFromDoc(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch product: $e';
    }
  }

  /// Add a new product
  Future<String> addProduct({
    required String name,
    required String description,
    required String category,
    required double price,
    required ProductCondition condition,
    required bool isAuctionEnabled,
    String? imageUrl,
    required String sellerId,
    AvailabilityStatus availabilityStatus = AvailabilityStatus.available,
  }) async {
    try {
      final doc = await _firestore.collection('products').add({
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'condition': condition.index,
        'isAuctionEnabled': isAuctionEnabled,
        'imageUrl': imageUrl,
        'sellerId': sellerId,
        'availabilityStatus': availabilityStatus.index,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      throw 'Failed to add product: $e';
    }
  }

  /// Update product
  Future<void> updateProduct(
    String productId, {
    String? name,
    String? description,
    String? category,
    double? price,
    ProductCondition? condition,
    bool? isAuctionEnabled,
    String? imageUrl,
    AvailabilityStatus? availabilityStatus,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;
      if (price != null) updates['price'] = price;
      if (condition != null) updates['condition'] = condition.index;
      if (isAuctionEnabled != null)
        updates['isAuctionEnabled'] = isAuctionEnabled;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (availabilityStatus != null)
        updates['availabilityStatus'] = availabilityStatus.index;

      await _firestore.collection('products').doc(productId).update(updates);
    } catch (e) {
      throw 'Failed to update product: $e';
    }
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      throw 'Failed to delete product: $e';
    }
  }

  /// Stream of all products (real-time)
  Stream<List<Product>> getAllProductsStream() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return _productFromDoc(doc);
      }).toList();
    });
  }

  /// Stream of products by seller (real-time)
  Stream<List<Product>> getSellerProductsStream(String sellerId) {
    return _firestore
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _productFromDoc(doc);
      }).toList();
    });
  }

  /// Convert Firestore document to Product object
  Product _productFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'All',
      price: (data['price'] ?? 0.0).toDouble(),
      condition: ProductCondition.values[data['condition'] ?? 0],
      isAuctionEnabled: data['isAuctionEnabled'] ?? false,
      imageUrl: data['imageUrl'],
      sellerId: data['sellerId'],
      availabilityStatus:
          AvailabilityStatus.values[data['availabilityStatus'] ?? 0],
    );
  }
}
