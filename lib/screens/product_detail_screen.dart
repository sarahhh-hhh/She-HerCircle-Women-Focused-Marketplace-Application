import 'package:flutter/material.dart';
import 'package:she_her_circle/models/product.dart';
import 'package:she_her_circle/services/image_service.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrl != null)
              ImageService.displayImage(
                product.imageUrl,
                fit: BoxFit.cover,
                height: 200,
                width: double.infinity,
                borderRadius: BorderRadius.circular(12),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Icon(Icons.image_not_supported,
                    size: 48, color: Colors.grey[600]),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(product.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                Text('৳${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(label: Text(product.category)),
                const SizedBox(width: 8),
                Chip(
                    label: Text(product.condition == ProductCondition.newItem
                        ? 'New'
                        : 'Used')),
                const SizedBox(width: 8),
                if (product.isAuctionEnabled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Auction Enabled',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(product.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
