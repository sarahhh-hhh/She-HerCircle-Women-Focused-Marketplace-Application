import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:she_her_circle/models/order.dart' as models;
import 'package:she_her_circle/models/product.dart';
import 'package:she_her_circle/screens/auth_landing_screen.dart';
import 'package:she_her_circle/screens/seller_dashboard_screen.dart';
import 'package:she_her_circle/services/auth_service.dart';
import 'package:she_her_circle/services/image_service.dart';
import 'package:she_her_circle/services/order_service.dart';
import 'package:she_her_circle/services/product_service.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  late String _sellerId;
  List<Product> _sellerProducts = [];
  late StreamSubscription<List<Product>> _sellerProductsSubscription;
  final TextEditingController _nicknameController = TextEditingController();
  bool _savingNickname = false;
  bool _backfillInProgress = false;
  bool _creatingProfileDoc = false;

  @override
  void initState() {
    super.initState();
    _sellerId = _authService.getCurrentUser()!.uid;
    _sellerProductsSubscription =
        _productService.getSellerProductsStream(_sellerId).listen((products) {
      if (!mounted) return;
      setState(() {
        _sellerProducts = products;
      });
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _sellerProductsSubscription.cancel();
    super.dispose();
  }

  // Real-time stream handles seller products; legacy loader removed.

  List<Product> get _auctionProducts =>
      _sellerProducts.where((product) => product.isAuctionEnabled).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Home'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          _buildOrdersTab(),
          _buildAuctionTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Auction',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildDashboard() {
    return SellerDashboardScreen(sellerId: _sellerId);
  }

  Widget _buildOrdersTab() {
    return StreamBuilder<List<models.Order>>(
      stream: _orderService.streamSellerOrders(_sellerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Seller orders stream error: ${snapshot.error}');
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
                leading: const Icon(Icons.shopping_bag),
                title: Text(order.productName),
                subtitle: Text(
                    'Qty: ${order.quantity} • ৳${order.price.toStringAsFixed(2)}'),
                trailing: SizedBox(
                  width: 140,
                  child: FittedBox(
                    alignment: Alignment.topRight,
                    child: _OrderActions(
                      order: order,
                      onUpdate: (status) => _orderService.updateStatus(
                        order.id,
                        status,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuctionTab() {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _auctionProducts.length,
            itemBuilder: (context, index) {
              final product = _auctionProducts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: _ListingImage(imageUrl: product.imageUrl),
                  ),
                  title: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        product.category,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${product.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Auction',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        final role = (data['role'] as String?) ?? 'seller';
        final nickname = (data['nickname'] as String?) ?? '';
        var nicknameLocked = (data['nicknameLocked'] as bool?) ?? false;
        final hasNickname = nickname.trim().isNotEmpty;
        final user = FirebaseAuth.instance.currentUser;
        final isVerified = user?.emailVerified == true;

        // If locked but nickname never set (older data), unlock once so user can set it
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

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nickname: ' + (hasNickname ? nickname : 'not set'),
                            style: Theme.of(context).textTheme.titleLarge,
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
                      const SizedBox(height: 8),
                      Text('Role: $role',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Text(
                          'Verification: ${isVerified ? 'Verified' : 'Not verified'}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 6),
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
    );
  }
}

extension on _SellerHomeScreenState {
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

class _ListingImage extends StatelessWidget {
  final String? imageUrl;
  const _ListingImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child:
            Icon(Icons.image_not_supported, size: 28, color: Colors.grey[600]),
      );
    }

    return ImageService.displayImage(
      imageUrl,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

class _OrderActions extends StatelessWidget {
  final models.Order order;
  final Future<void> Function(models.OrderStatus) onUpdate;
  const _OrderActions({required this.order, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(order.status.name),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: actions),
        ],
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    List<Widget> actions;
    switch (order.status) {
      case models.OrderStatus.pending:
        actions = [
          _smallButton('Accept', () => onUpdate(models.OrderStatus.accepted)),
          _smallButton('Cancel', () => onUpdate(models.OrderStatus.canceled),
              color: Colors.red),
        ];
        break;
      case models.OrderStatus.accepted:
        actions = [
          _smallButton('Ship', () => onUpdate(models.OrderStatus.shipped)),
          _smallButton('Cancel', () => onUpdate(models.OrderStatus.canceled),
              color: Colors.red),
        ];
        break;
      case models.OrderStatus.paid:
        actions = [
          _smallButton('Ship', () => onUpdate(models.OrderStatus.shipped)),
        ];
        break;
      case models.OrderStatus.shipped:
        actions = [Text('Awaiting buyer', style: _muted(context))];
        break;
      case models.OrderStatus.complete:
        actions = [Text('Completed', style: _muted(context))];
        break;
      case models.OrderStatus.canceled:
        actions = [Text('Canceled', style: _muted(context))];
        break;
    }
    return actions;
  }

  TextStyle? _muted(BuildContext context) {
    return Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.grey[600]);
  }

  Widget _smallButton(String label, VoidCallback onPressed, {Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        backgroundColor: color,
        minimumSize: const Size(0, 0),
      ),
      child: Text(label),
    );
  }
}
