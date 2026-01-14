import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Enhanced product list item with selection, stock indicators, and quick actions
class ProductListItem extends StatelessWidget {
  final DocumentSnapshot product;
  final bool isSelected;
  final bool isSelectionMode;
  final Function(bool?) onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final Function(int) onStockAdjust;

  const ProductListItem({
    super.key,
    required this.product,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    required this.onStockAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final data = product.data() as Map<String, dynamic>;
    final stockQuantity = data['stock_quantity'] ?? 0;
    final price = data['price'] ?? 0;
    final name = data['name'] ?? 'Unknown Product';
    final unit = data['unit'] ?? '';
    final imageUrl = data['imageUrl'];

    final isLowStock = stockQuantity > 0 && stockQuantity < 5;
    final isOutOfStock = stockQuantity == 0;

    // Get stock color
    final stockColor = isOutOfStock
        ? Colors.red
        : isLowStock
            ? Colors.orange
            : Colors.green;

    // Format date
    String date = 'Unknown Date';
    if (data['created_at'] != null && data['created_at'] is Timestamp) {
      date = DateFormat('MMM d, y').format(
        (data['created_at'] as Timestamp).toDate(),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: Colors.deepOrange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isSelectionMode ? () => onSelected(!isSelected) : onTap,
        onLongPress: isSelectionMode ? null : () => onSelected(true),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Selection checkbox (if in selection mode)
              if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: onSelected,
                  activeColor: Colors.deepOrange,
                ),

              // Product image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                  image: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl == null || imageUrl.toString().isEmpty
                    ? const Icon(Icons.image, color: Colors.grey, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name with badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLowStock) _buildStockBadge('LOW', Colors.orange),
                        if (isOutOfStock)
                          _buildStockBadge('OUT', Colors.red),
                      ],
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Added: $date',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Stock and price info
                    Row(
                      children: [
                        Icon(Icons.inventory, size: 14, color: stockColor),
                        const SizedBox(width: 4),
                        Text(
                          'Stock: $stockQuantity',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.currency_rupee,
                            size: 14, color: Colors.green),
                        Text(
                          '$price',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons (hidden in selection mode)
              if (!isSelectionMode)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick stock adjustment buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 20),
                          onPressed: stockQuantity > 0
                              ? () => onStockAdjust(-1)
                              : null,
                          color: Colors.red[700],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => onStockAdjust(1),
                          color: Colors.green[700],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    // Edit and Delete buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: onEdit,
                          color: Colors.blue[700],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: onDelete,
                          color: Colors.red[700],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
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
    );
  }

  Widget _buildStockBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
