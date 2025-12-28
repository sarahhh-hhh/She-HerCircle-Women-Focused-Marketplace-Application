import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:she_her_circle/models/order.dart' as models;
import 'package:she_her_circle/models/product.dart';
import 'package:she_her_circle/screens/auth_landing_screen.dart';
import 'package:she_her_circle/screens/product_detail_screen.dart';
import 'package:she_her_circle/services/image_service.dart';
import 'package:she_her_circle/services/order_service.dart';
import 'package:she_her_circle/services/product_service.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final List<String> _categories = [
    'All',
    'Hair',
    'Body',
    'Clothes',
    'Accessories'
  ];
  String _selectedCategory = 'All';
  int _currentIndex = 0;
  final Map<String, int> _cart = {};
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final TextEditingController _nicknameController = TextEditingController();
  bool _placingOrder = false;
  bool _savingNickname = false;
  bool _backfillInProgress = false;
  bool _creatingProfileDoc = false;
  late StreamSubscription<List<Product>> _productsSubscription;

  List<Product> get _filteredProducts {
    final allProducts =
        _availableProducts.where((p) => !p.isAuctionEnabled).toList();
    if (_selectedCategory == 'All') return allProducts;
    return allProducts.where((p) => p.category == _selectedCategory).toList();
  }

  List<Product> get _auctionProducts =>
      _allProducts.where((p) => p.isAuctionEnabled).toList();

  List<Product> get _availableProducts {
    // Return all products not in cart
    return _allProducts.where((p) => !_cart.containsKey(p.id)).toList();
  }

  late List<Product> _allProducts = [];

  @override
  void initState() {
    super.initState();
    _productsSubscription =
        _productService.getAllProductsStream().listen((products) {
      if (!mounted) return;
      setState(() {
        _allProducts = products;
      });
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _productsSubscription.cancel();
    super.dispose();
  }

  int _productQuantity(Product product) => _cart[product.id] ?? 0;

  void _increment(Product product) {
    setState(() {
      _cart.update(product.id, (value) => value + 1, ifAbsent: () => 1);
    });
  }

  void _decrement(Product product) {
    setState(() {
      final current = _cart[product.id] ?? 0;
      if (current <= 1) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = current - 1;
      }
    });
  }

  double get _cartTotal {
    double total = 0;
    for (final entry in _cart.entries) {
      final product = _allProducts.firstWhere((p) => p.id == entry.key);
      total += product.price * entry.value;
    }
    return total;
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Widget _buildAuctionTab() {
    final isFriday = DateTime.now().weekday == DateTime.friday;

    if (_auctionProducts.isEmpty) {
      return const Center(child: Text('No auction items available.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Weekly Auction',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _auctionProducts.length,
            itemBuilder: (context, index) {
              final product = _auctionProducts[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: _AuctionImage(imageUrl: product.imageUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(product.category,
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 6),
                            Text('৳${product.price.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            isFriday ? () => _showBidDialog(product) : null,
                        child: Text(isFriday ? 'Bid' : 'Friday Only'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBidDialog(Product product) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bid on ${product.name}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Bid amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bid placed (demo)')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkoutCart() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    setState(() => _placingOrder = true);
    try {
      final requests = <OrderCreateRequest>[];
      for (final entry in _cart.entries) {
        final product = _allProducts.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => throw 'Product not found',
        );
        if (product.sellerId == null) {
          throw 'Product seller missing';
        }
        requests.add(OrderCreateRequest(
          sellerId: product.sellerId!,
          productId: product.id,
          productName: product.name,
          productImageUrl: product.imageUrl,
          price: product.price * entry.value,
          quantity: entry.value,
        ));
      }

      await _orderService.createOrders(buyerId: uid, orders: requests);
      setState(() => _cart.clear());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Placed ${requests.length} order(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('She&HerCircle'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home tab
          Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Browse by category',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final selected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) => _onCategorySelected(cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Products',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(child: Text('No products'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = _filteredProducts[index];
                          return _ProductBox(
                            product: p,
                            quantity: _productQuantity(p),
                            onAdd: () => _increment(p),
                            onRemove: () => _decrement(p),
                          );
                        },
                      ),
              ),
            ],
          ),

          // Cart
          _CartView(
            cart: _cart,
            products: _allProducts,
            onAdd: _increment,
            onRemove: _decrement,
            total: _cartTotal,
            onCheckout: _placingOrder ? null : _checkoutCart,
            placingOrder: _placingOrder,
          ),

          // Orders
          _OrdersTab(orderService: _orderService),

          // Auction
          _buildAuctionTab(),

          // Profile
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (!_creatingProfileDoc && uid != null) {
                  _creatingProfileDoc = true;
                  FirebaseFirestore.instance.collection('users').doc(uid).set({
                    'nickname': '',
                    'nicknameLocked': false,
                  }, SetOptions(merge: true)).whenComplete(() {
                    _creatingProfileDoc = false;
                  });
                }
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() ?? {};
              final role = (data['role'] as String?) ?? 'buyer';
              final nickname = (data['nickname'] as String?) ?? '';
              var nicknameLocked = (data['nicknameLocked'] as bool?) ?? false;
              final hasNickname = nickname.trim().isNotEmpty;
              final user = FirebaseAuth.instance.currentUser;
              final isVerified = user?.emailVerified == true;

              // Backfill missing fields once if needed (merge only, no overwrite)
              if (!_backfillInProgress && !data.containsKey('nicknameLocked')) {
                final uid = user?.uid;
                if (uid != null) {
                  _backfillInProgress = true;
                  FirebaseFirestore.instance.collection('users').doc(uid).set({
                    'nicknameLocked': false,
                  }, SetOptions(merge: true)).whenComplete(() {
                    _backfillInProgress = false;
                  });
                }
              }

              // If locked but nickname missing (old data), unlock once so user can set it
              if (!hasNickname && nicknameLocked) {
                final uid = user?.uid;
                if (uid != null) {
                  nicknameLocked = false;
                  FirebaseFirestore.instance.collection('users').doc(uid).set({
                    'nicknameLocked': false,
                  }, SetOptions(merge: true));
                }
              }

              final canSetNickname = !nicknameLocked && !hasNickname;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Nickname: ' +
                                      (hasNickname ? nickname : 'not set'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(width: 6),
                                if (nicknameLocked || hasNickname)
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Role: $role',
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 6),
                            Text(
                                'Verification: ${isVerified ? 'Verified' : 'Not verified'}',
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            if (canSetNickname) ...[
                              TextField(
                                controller: _nicknameController,
                                maxLength: 20,
                                decoration: const InputDecoration(
                                  labelText: 'Set nickname (one-time)',
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: _savingNickname
                                      ? null
                                      : () async {
                                          await _saveNickname();
                                        },
                                  child: _savingNickname
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const AuthLandingScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text('Logout'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Auction'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

extension on _BuyerHomeScreenState {
  Future<void> _saveNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final newNickname = _nicknameController.text.trim();
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    if (newNickname.length < 3 ||
        newNickname.length > 20 ||
        !regex.hasMatch(newNickname)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Nickname must be 3–20 characters (letters, numbers, _)'),
        ),
      );
      return;
    }

    setState(() => _savingNickname = true);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final ref = FirebaseFirestore.instance.collection('users').doc(uid);
        final snap = await tx.get(ref);
        final existingNickname = ((snap.data()?['nickname'] ?? '') as String);
        final locked = ((snap.data()?['nicknameLocked'] ?? false) as bool);
        if (locked || existingNickname.trim().isNotEmpty) {
          throw 'NICKNAME_ALREADY_SET';
        }
        tx.update(ref, {
          'nickname': newNickname,
          'nicknameLocked': true,
          'nicknameSetAt': FieldValue.serverTimestamp(),
        });
      });
      _nicknameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nickname saved')),
      );
    } catch (e) {
      final already = e.toString().contains('NICKNAME_ALREADY_SET');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(already
                ? 'Nickname already set.'
                : 'Failed to save nickname.')),
      );
    } finally {
      if (mounted) setState(() => _savingNickname = false);
    }
  }
}

class _ProductBox extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductBox({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ));
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  _buildImage(context),
                  // Auction badge
                  if (product.isAuctionEnabled)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Auction',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ),
                  // Condition badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.condition == ProductCondition.newItem
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.condition == ProductCondition.newItem
                            ? 'New'
                            : 'Used',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  // Availability status badge
                  if (product.availabilityStatus !=
                      AvailabilityStatus.available)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: product.availabilityStatus ==
                                  AvailabilityStatus.outOfStock
                              ? Colors.red
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.availabilityStatus ==
                                  AvailabilityStatus.outOfStock
                              ? 'Out of Stock'
                              : 'Not Available',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.category,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Availability Status and Cart Controls
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Availability status text
                        if (product.availabilityStatus !=
                            AvailabilityStatus.available)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  product.availabilityStatus ==
                                          AvailabilityStatus.outOfStock
                                      ? Icons.remove_shopping_cart
                                      : Icons.block,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    product.availabilityStatus ==
                                            AvailabilityStatus.outOfStock
                                        ? 'Out of Stock'
                                        : 'Not Available',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Price and Cart Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '৳${product.price.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: product.availabilityStatus ==
                                            AvailabilityStatus.available
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                  ),
                            ),
                            if (product.availabilityStatus ==
                                AvailabilityStatus.available)
                              if (quantity > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: onRemove,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Text(
                                        quantity.toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: onAdd,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                InkWell(
                                  onTap: onAdd,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                            else
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.block,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (product.imageUrl == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        alignment: Alignment.center,
        child:
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey[600]),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ImageService.displayImage(
        product.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ));
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              _buildImage(context),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(product.category,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                              product.condition == ProductCondition.newItem
                                  ? 'New'
                                  : 'Used'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantity > 0 ? onRemove : null,
                      ),
                      Text(quantity.toString()),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: onAdd,
                      ),
                    ],
                  ),
                  if (product.isAuctionEnabled)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Auction',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (product.imageUrl == null) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      );
    }

    return ImageService.displayImage(
      product.imageUrl,
      fit: BoxFit.cover,
      width: 72,
      height: 72,
      borderRadius: BorderRadius.circular(12),
    );
  }
}

class _AuctionImage extends StatelessWidget {
  final String? imageUrl;
  const _AuctionImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      );
    }

    return ImageService.displayImage(
      imageUrl,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

class _CartView extends StatelessWidget {
  final Map<String, int> cart;
  final List<Product> products;
  final void Function(Product) onAdd;
  final void Function(Product) onRemove;
  final double total;
  final VoidCallback? onCheckout;
  final bool placingOrder;

  const _CartView({
    required this.cart,
    required this.products,
    required this.onAdd,
    required this.onRemove,
    required this.total,
    required this.onCheckout,
    required this.placingOrder,
  });

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(child: Text('Your cart is empty'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: cart.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = cart.entries.elementAt(index);
              final product = products.firstWhere((p) => p.id == entry.key,
                  orElse: () => products.first);
              final qty = entry.value;
              return Card(
                child: ListTile(
                  leading: product.imageUrl != null
                      ? ImageService.displayImage(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : const Icon(Icons.shopping_bag),
                  title: Text(product.name),
                  subtitle: Text('৳${product.price.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => onRemove(product),
                      ),
                      Text(qty.toString()),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => onAdd(product),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text('৳${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCheckout,
              child: placingOrder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Checkout'),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final OrderService orderService;
  const _OrdersTab({required this.orderService});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to view orders'));
    }

    return StreamBuilder<List<models.Order>>(
      stream: orderService.streamBuyerOrders(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Orders stream error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Failed to load orders: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            (snapshot.data == null || snapshot.data!.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('No orders yet'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isThreeLine: true,
                leading: const Icon(Icons.receipt_long),
                title: Text(order.productName),
                subtitle: Text(
                  'Qty: ${order.quantity} • ৳${order.price.toStringAsFixed(2)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: SizedBox(
                  width: 160,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(order.status.name),
                      const SizedBox(height: 4),
                      if (order.status == models.OrderStatus.shipped)
                        ElevatedButton(
                          onPressed: () => orderService.updateStatus(
                              order.id, models.OrderStatus.complete),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Mark Received'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
