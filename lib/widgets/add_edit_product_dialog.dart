import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:she_her_circle/models/product.dart';
import 'package:she_her_circle/services/image_service.dart';
import 'package:she_her_circle/services/product_service.dart';

class AddEditProductDialog extends StatefulWidget {
  final Product? product;
  final String sellerId;
  final Function(Product) onProductSaved;

  const AddEditProductDialog({
    Key? key,
    this.product,
    required this.sellerId,
    required this.onProductSaved,
  }) : super(key: key);

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  late String _selectedCategory;
  late ProductCondition _selectedCondition;
  late bool _isAuctionEnabled;
  late AvailabilityStatus _selectedAvailability;

  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;

  final List<String> _categories = [
    'Hair',
    'Body',
    'Clothes',
    'Accessories',
    'Other',
  ];

  final ImageService _imageService = ImageService();
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController = TextEditingController(text: widget.product!.name);
      _descriptionController =
          TextEditingController(text: widget.product!.description);
      _priceController =
          TextEditingController(text: widget.product!.price.toStringAsFixed(2));
      _selectedCategory = widget.product!.category;
      _selectedCondition = widget.product!.condition;
      _isAuctionEnabled = widget.product!.isAuctionEnabled;
      _selectedAvailability = widget.product!.availabilityStatus;
      _existingImageUrl = widget.product!.imageUrl;
    } else {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _priceController = TextEditingController();
      _selectedCategory = _categories.first;
      _selectedCondition = ProductCondition.newItem;
      _isAuctionEnabled = false;
      _selectedAvailability = AvailabilityStatus.available;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imageService.pickImageFromGallery();
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _priceController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (widget.product == null && _selectedImage == null) {
      _showError('Please select an image for new products');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        // Delete old image if editing
        if (_existingImageUrl != null && widget.product != null) {
          try {
            await _imageService.deleteImage(_existingImageUrl!);
          } catch (e) {
            debugPrint('Failed to delete old image: $e');
          }
        }

        // Upload and resize new image
        try {
          print(
              'Starting image processing for productId: ${widget.product?.id ?? DateTime.now().millisecondsSinceEpoch.toString()}');
          imageUrl = await _imageService.resizeImageToDataUrl(
            imageFile: _selectedImage!,
          );
          print('Image processing successful, data URL created');
        } catch (imageError) {
          print('Image processing failed: $imageError');
          _showError(
              'Image processing failed: $imageError\n\nTips:\n• Try a different image\n• Check image format (JPG, PNG)\n• Try a smaller image');
          setState(() => _isLoading = false);
          return;
        }
      }

      final price = double.parse(_priceController.text);

      if (widget.product != null) {
        // Update existing product
        await _productService.updateProduct(
          widget.product!.id,
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          price: price,
          condition: _selectedCondition,
          isAuctionEnabled: _isAuctionEnabled,
          imageUrl: imageUrl,
          availabilityStatus: _selectedAvailability,
        );

        final updatedProduct = widget.product!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          price: price,
          condition: _selectedCondition,
          isAuctionEnabled: _isAuctionEnabled,
          imageUrl: imageUrl,
          availabilityStatus: _selectedAvailability,
        );

        widget.onProductSaved(updatedProduct);
      } else {
        // Create new product
        final productId = await _productService.addProduct(
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          price: price,
          condition: _selectedCondition,
          isAuctionEnabled: _isAuctionEnabled,
          imageUrl: imageUrl,
          sellerId: widget.sellerId,
          availabilityStatus: _selectedAvailability,
        );

        final newProduct = Product(
          id: productId,
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          price: price,
          condition: _selectedCondition,
          isAuctionEnabled: _isAuctionEnabled,
          imageUrl: imageUrl,
          sellerId: widget.sellerId,
          availabilityStatus: _selectedAvailability,
        );

        widget.onProductSaved(newProduct);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product != null
                  ? 'Product updated successfully'
                  : 'Product created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save product: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product != null ? 'Edit Product' : 'Add Product'),
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _selectedImage != null
                      ? Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.cover,
                        )
                      : _existingImageUrl != null
                          ? ImageService.displayImage(
                              _existingImageUrl,
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 40, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to select image',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 20),
              // Product name
              TextField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  hintText: 'Enter product name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Product description
              TextField(
                controller: _descriptionController,
                enabled: !_isLoading,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter product description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                items: _categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Price
              TextField(
                controller: _priceController,
                enabled: !_isLoading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price (৳)',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Condition dropdown
              DropdownButtonFormField<ProductCondition>(
                initialValue: _selectedCondition,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCondition = value);
                        }
                      },
                items: ProductCondition.values
                    .map((cond) => DropdownMenuItem(
                          value: cond,
                          child: Text(cond.name == 'newItem' ? 'New' : 'Used'),
                        ))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Condition',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Availability status dropdown
              DropdownButtonFormField<AvailabilityStatus>(
                initialValue: _selectedAvailability,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedAvailability = value);
                        }
                      },
                items: AvailabilityStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(
                            status.name == 'available'
                                ? 'Available'
                                : status.name == 'outOfStock'
                                    ? 'Out of Stock'
                                    : 'Archived',
                          ),
                        ))
                    .toList(),
                decoration: InputDecoration(
                  labelText: 'Availability Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Auction checkbox
              CheckboxListTile(
                value: _isAuctionEnabled,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() => _isAuctionEnabled = value ?? false);
                      },
                title: const Text('Enable for Auction'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.product != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
