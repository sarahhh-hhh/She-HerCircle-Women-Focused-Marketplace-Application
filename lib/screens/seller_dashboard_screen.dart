import 'package:flutter/material.dart';
import 'package:she_her_circle/models/product.dart';
import 'package:she_her_circle/services/image_service.dart';
import 'package:she_her_circle/services/product_service.dart';
import 'package:she_her_circle/widgets/add_edit_product_dialog.dart';

class SellerDashboardScreen extends StatefulWidget {
  final String sellerId;

  const SellerDashboardScreen({
    Key? key,
    required this.sellerId,
  }) : super(key: key);

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final ProductService _productService = ProductService();
  final ImageService _imageService = ImageService();
  List<Product> _sellerProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSellerProducts();
  }

  Future<void> _loadSellerProducts() async {
    try {
      setState(() => _isLoading = true);
      final products = await _productService.getAllProducts();
      final sellerProducts = products
          .where((p) => p.sellerId == widget.sellerId && !p.isAuctionEnabled)
          .toList();
      setState(() {
        _sellerProducts = sellerProducts;
      });
    } catch (e) {
      _showError('Failed to load products: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete image from storage
        if (product.imageUrl != null) {
          try {
            await _imageService.deleteImage(product.imageUrl!);
          } catch (e) {
            debugPrint('Failed to delete image: $e');
          }
        }

        // Delete product from database
        await _productService.deleteProduct(product.id);

        setState(() {
          _sellerProducts.removeWhere((p) => p.id == product.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product "${product.name}" deleted')),
        );
      } catch (e) {
        _showError('Failed to delete product: $e');
      }
    }
  }

  void _showAddProductDialog() {
    debugPrint('FAB clicked - opening dialog...');
    try {
      debugPrint('sellerId: ${widget.sellerId}');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          debugPrint('Dialog builder called');
          return AddEditProductDialog(
            sellerId: widget.sellerId,
            onProductSaved: (product) {
              debugPrint('Product saved: ${product.name}');
              if (mounted) {
                setState(() {
                  _sellerProducts.add(product);
                });
                _loadSellerProducts();
              }
            },
          );
        },
      ).then((value) {
        debugPrint('Dialog closed');
      }).catchError((e) {
        debugPrint('Error showing dialog: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open dialog: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error in _showAddProductDialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditProductDialog(Product product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddEditProductDialog(
        product: product,
        sellerId: widget.sellerId,
        onProductSaved: (updatedProduct) {
          if (mounted) {
            setState(() {
              final index =
                  _sellerProducts.indexWhere((p) => p.id == updatedProduct.id);
              if (index >= 0) {
                _sellerProducts[index] = updatedProduct;
              }
            });
            _loadSellerProducts();
          }
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getAvailabilityStatusLabel(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.outOfStock:
        return 'Out of Stock';
      case AvailabilityStatus.archived:
        return 'Archived';
    }
  }

  Color _getAvailabilityStatusColor(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return Colors.green;
      case AvailabilityStatus.outOfStock:
        return Colors.orange;
      case AvailabilityStatus.archived:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sellerProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No products yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first product to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sellerProducts.length,
                  itemBuilder: (context, index) {
                    final product = _sellerProducts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product image
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[200],
                                  ),
                                  child: product.imageUrl != null
                                      ? ImageService.displayImage(
                                          product.imageUrl,
                                          fit: BoxFit.cover,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        )
                                      : Icon(Icons.image_not_supported,
                                          color: Colors.grey[400]),
                                ),
                                const SizedBox(width: 12),
                                // Product details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        product.category,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '৳${product.price.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _getAvailabilityStatusColor(
                                                      product
                                                          .availabilityStatus),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getAvailabilityStatusLabel(
                                                  product.availabilityStatus),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          if (product.isAuctionEnabled) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Auction',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Description
                            Text(
                              product.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            // Condition
                            Row(
                              children: [
                                Text(
                                  'Condition: ',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  product.condition.name == 'newItem'
                                      ? 'New'
                                      : 'Used',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      _showEditProductDialog(product),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _deleteProduct(product),
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  label: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint('FAB pressed!');
          // Test with simple alert first
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Test'),
              content:
                  const Text('FAB is working! Now opening product dialog...'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddProductDialog();
                  },
                  child: const Text('Continue'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }
}
