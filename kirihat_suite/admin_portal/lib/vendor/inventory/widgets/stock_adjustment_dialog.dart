import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog for adjusting product stock quantity
class StockAdjustmentDialog extends StatefulWidget {
  final String productName;
  final int currentStock;
  final Function(int) onAdjust;

  const StockAdjustmentDialog({
    super.key,
    required this.productName,
    required this.currentStock,
    required this.onAdjust,
  });

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  late int _newStock;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newStock = widget.currentStock;
    _controller.text = _newStock.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateStock(int delta) {
    setState(() {
      _newStock = (_newStock + delta).clamp(0, 999999);
      _controller.text = _newStock.toString();
    });
  }

  void _onManualInput(String value) {
    setState(() {
      _newStock = int.tryParse(value) ?? widget.currentStock;
      _newStock = _newStock.clamp(0, 999999);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adjustment = _newStock - widget.currentStock;
    final isIncreasing = adjustment > 0;
    final isDecreasing = adjustment < 0;

    return AlertDialog(
      title: const Text('Adjust Stock'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              widget.productName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Current stock
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Stock:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${widget.currentStock}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stock adjustment controls
            const Text(
              'New Stock Quantity',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),

            // Increment/Decrement buttons
            Row(
              children: [
                // Decrement buttons
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _updateStock(-10),
                      icon: const Icon(Icons.fast_rewind),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    IconButton(
                      onPressed: () => _updateStock(-1),
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Manual input field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                    ),
                    onChanged: _onManualInput,
                  ),
                ),
                const SizedBox(width: 16),

                // Increment buttons
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _updateStock(10),
                      icon: const Icon(Icons.fast_forward),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green[50],
                        foregroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    IconButton(
                      onPressed: () => _updateStock(1),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green[50],
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Adjustment preview
            if (adjustment != 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isIncreasing
                      ? Colors.green[50]
                      : isDecreasing
                          ? Colors.red[50]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isIncreasing
                        ? Colors.green
                        : isDecreasing
                            ? Colors.red
                            : Colors.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isIncreasing
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: isIncreasing ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isIncreasing
                            ? 'Adding $adjustment units'
                            : 'Removing ${adjustment.abs()} units',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isIncreasing ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Quick adjustment buttons
            const Text(
              'Quick Adjustments',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickButton('+5', 5),
                _buildQuickButton('+10', 10),
                _buildQuickButton('+50', 50),
                _buildQuickButton('-5', -5),
                _buildQuickButton('-10', -10),
                _buildQuickButton('Reset', widget.currentStock - _newStock),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: adjustment == 0
              ? null
              : () {
                  widget.onAdjust(adjustment);
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isIncreasing ? Colors.green : Colors.deepOrange,
          ),
          child: const Text('Update Stock'),
        ),
      ],
    );
  }

  Widget _buildQuickButton(String label, int delta) {
    return OutlinedButton(
      onPressed: () => _updateStock(delta),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
