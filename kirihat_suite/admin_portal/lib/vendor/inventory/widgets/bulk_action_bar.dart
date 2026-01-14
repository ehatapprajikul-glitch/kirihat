import 'package:flutter/material.dart';

/// Action bar shown when products are selected for bulk operations
class BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onChangeCategory;
  final VoidCallback onAdjustStock;
  final VoidCallback? onSetLocation;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    required this.onDelete,
    required this.onChangeCategory,
    required this.onAdjustStock,
    this.onSetLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepOrange[50],
        border: Border(
          bottom: BorderSide(color: Colors.deepOrange[200]!, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Selection count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          const Spacer(),
          
          // Action buttons
          if (onSetLocation != null) ...[
            IconButton(
              onPressed: onSetLocation,
              icon: const Icon(Icons.location_on),
              tooltip: 'Set Location',
              color: Colors.green[700],
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          IconButton(
            onPressed: onChangeCategory,
            icon: const Icon(Icons.category),
            tooltip: 'Change Category',
            color: Colors.deepOrange[700],
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          
          IconButton(
            onPressed: onAdjustStock,
            icon: const Icon(Icons.inventory),
            tooltip: 'Adjust Stock',
            color: Colors.blue[700],
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Selected',
            color: Colors.red[700],
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          
          // Cancel button
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
