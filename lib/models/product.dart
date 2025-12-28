enum ProductCondition { newItem, used }

enum AvailabilityStatus { available, outOfStock, archived }

class Product {
  final String id;
  final String name;
  final String description;
  final String category; // e.g., Hair, Body, Clothes, Accessories
  final double price;
  final ProductCondition condition;
  final bool isAuctionEnabled;
  final String? imageUrl;
  final String? sellerId;
  final AvailabilityStatus availabilityStatus;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.condition,
    required this.isAuctionEnabled,
    this.imageUrl,
    this.sellerId,
    this.availabilityStatus = AvailabilityStatus.available,
  });

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? price,
    ProductCondition? condition,
    bool? isAuctionEnabled,
    String? imageUrl,
    String? sellerId,
    AvailabilityStatus? availabilityStatus,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      isAuctionEnabled: isAuctionEnabled ?? this.isAuctionEnabled,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'condition': condition.index,
      'isAuctionEnabled': isAuctionEnabled,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'availabilityStatus': availabilityStatus.index,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      condition: ProductCondition.values[map['condition'] as int],
      isAuctionEnabled: map['isAuctionEnabled'] as bool,
      imageUrl: map['imageUrl'] as String?,
      sellerId: map['sellerId'] as String?,
      availabilityStatus:
          AvailabilityStatus.values[map['availabilityStatus'] as int? ?? 0],
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, description: $description, category: $category, price: $price, condition: $condition, isAuctionEnabled: $isAuctionEnabled, imageUrl: $imageUrl, sellerId: $sellerId, availabilityStatus: $availabilityStatus)';
  }
}
