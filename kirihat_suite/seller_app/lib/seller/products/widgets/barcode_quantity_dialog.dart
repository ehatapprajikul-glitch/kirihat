import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/barcode_printer_service.dart';

/// Dialog for selecting products and quantities for barcode printing
class BarcodeQuantityDialog extends StatefulWidget {
  final List<Map<String, dynamic>> selectedProducts;

  const BarcodeQuantityDialog({
    super.key,
    required this.selectedProducts,
  });

  @override
  State<BarcodeQuantityDialog> createState() => _BarcodeQuantityDialogState();
}

class _BarcodeQuantityDialogState extends State<BarcodeQuantityDialog> {
  final Map<String, int> _quantities = {};
  final BarcodePrinterService _printerService = BarcodePrinterService();
  bool _isPrinting = false;
  
  // Layout mode settings
  LayoutMode _selectedLayout = LayoutMode.grid;
  int _gridColumns = 2;
  int _gridRows = 7;

  @override
  void initState() {
    super.initState();
    // Initialize quantities to 1 for each product
    for (var product in widget.selectedProducts) {
      _quantities[product['id']] = 1;
    }
  }

  void _updateQuantity(String productId, int value) {
    setState(() {
      _quantities[productId] = value.clamp(1, 999);
    });
  }

  Future<void> _printBarcodes() async {
    setState(() => _isPrinting = true);
    
    try {
      // Build the map of products to quantities
      final Map<Map<String, dynamic>, int> productsWithQuantities = {};
      for (var product in widget.selectedProducts) {
        final quantity = _quantities[product['id']] ?? 1;
        productsWithQuantities[product] = quantity;
      }

      // Calculate total labels
      final totalLabels = _quantities.values.fold<int>(0, (sum, qty) => sum + qty);
      
      // Show confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Print'),
          content: Text(
            'Print $totalLabels barcode label(s) for ${widget.selectedProducts.length} product(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
              ),
              child: const Text('Print'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await _printerService.printBarcodes(
          context,
          productsWithQuantities,
          layoutMode: _selectedLayout,
          gridColumns: _gridColumns,
          gridRows: _gridRows,
        );
        
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barcodes sent to printer successfully'),
              backgroundColor: Color(0xFF0D9759),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLabels = _quantities.values.fold<int>(0, (sum, qty) => sum + qty);
    
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9759),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Print Barcode Labels',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedLayout == LayoutMode.grid
                              ? 'Grid Layout: $_gridColumns×$_gridRows (${_gridColumns * _gridRows} per page)'
                              : 'Paper Size: 4×6 inches | Barcode Width: 2 inches',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSummaryItem(
                    'Products',
                    '${widget.selectedProducts.length}',
                    Icons.inventory_2,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildSummaryItem(
                    'Total Labels',
                    '$totalLabels',
                    Icons.qr_code_2,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildSummaryItem(
                    'Pages',
                    '${_calculatePages(totalLabels)}',
                    Icons.description,
                  ),
                ],
              ),
            ),

            // Layout Mode Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Layout Mode:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLayoutOption(
                          LayoutMode.grid,
                          'Grid Layout',
                          'Multiple per page',
                          Icons.grid_on,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLayoutOption(
                          LayoutMode.twoPerPage,
                          '2 Per Page',
                          'Larger labels',
                          Icons.view_agenda,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedLayout == LayoutMode.grid) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Columns: $_gridColumns',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Slider(
                                value: _gridColumns.toDouble(),
                                min: 1,
                                max: 4,
                                divisions: 3,
                                activeColor: const Color(0xFF0D9759),
                                label: _gridColumns.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _gridColumns = value.toInt();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rows: $_gridRows',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Slider(
                                value: _gridRows.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                activeColor: const Color(0xFF0D9759),
                                label: _gridRows.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _gridRows = value.toInt();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Product list with quantities
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.selectedProducts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = widget.selectedProducts[index];
                  final productId = product['id'];
                  final quantity = _quantities[productId] ?? 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        // Product Image
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                            image: product['imageUrl'] != null
                                ? DecorationImage(
                                    image: NetworkImage(product['imageUrl']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: product['imageUrl'] == null
                              ? const Icon(Icons.image, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // Product Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${product['id']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quantity Controls
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: quantity > 1
                                    ? () => _updateQuantity(productId, quantity - 1)
                                    : null,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                              Container(
                                width: 60,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: TextField(
                                  controller: TextEditingController(text: '$quantity')
                                    ..selection = TextSelection.fromPosition(
                                      TextPosition(offset: '$quantity'.length),
                                    ),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  onChanged: (value) {
                                    final newQty = int.tryParse(value) ?? 1;
                                    _updateQuantity(productId, newQty);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: quantity < 999
                                    ? () => _updateQuantity(productId, quantity + 1)
                                    : null,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isPrinting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _printBarcodes,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(_isPrinting ? 'Printing...' : 'Print Barcodes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculatePages(int totalLabels) {
    if (_selectedLayout == LayoutMode.grid) {
      final labelsPerPage = _gridColumns * _gridRows;
      return (totalLabels / labelsPerPage).ceil();
    } else {
      return (totalLabels / 2).ceil();
    }
  }

  Widget _buildLayoutOption(
    LayoutMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedLayout == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLayout = mode;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9759) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? const Color(0xFF0D9759).withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0D9759) : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF0D9759) : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0D9759), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D9759),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
