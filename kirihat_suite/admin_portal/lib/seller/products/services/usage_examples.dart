import 'package:flutter/material.dart';
import 'barcode_printer_service.dart';

/// Example usage of the improved BarcodePrinterService

class BarcodeExampleUsage {
  final BarcodePrinterService _printerService = BarcodePrinterService();

  /// Example 1: Print in grid layout (like your uploaded image)
  /// This creates a page with multiple barcodes in a 2x7 grid
  Future<void> printGridLayout(BuildContext context) async {
    final productsWithQuantities = {
      {
        'id': 'PROD001',
        'name': 'Sample Product 1',
        'barcode': '2010101000951',
        'mrp': 299.99,
        'selling_price': 249.99,
      }: 5, // Print 5 labels for this product
      {
        'id': 'PROD002',
        'name': 'Sample Product 2',
        'barcode': '2010101000952',
        'mrp': 499.99,
        'selling_price': 449.99,
      }: 3, // Print 3 labels for this product
    };

    await _printerService.printBarcodes(
      context,
      productsWithQuantities,
      layoutMode: LayoutMode.grid,
      gridColumns: 2, // 2 columns
      gridRows: 7,    // 7 rows (14 barcodes per page)
    );
  }

  /// Example 2: Print in original 2-per-page layout
  Future<void> printTwoPerPage(BuildContext context) async {
    final productsWithQuantities = {
      {
        'id': 'PROD001',
        'name': 'Sample Product 1',
        'barcode': '2010101000951',
        'mrp': 299.99,
        'selling_price': 249.99,
      }: 2,
    };

    await _printerService.printBarcodes(
      context,
      productsWithQuantities,
      layoutMode: LayoutMode.twoPerPage,
    );
  }

  /// Example 3: Preview before printing (grid layout)
  Future<void> previewGridLayout(BuildContext context) async {
    final productsWithQuantities = {
      {
        'id': 'PROD001',
        'name': 'Sample Product 1',
        'barcode': '2010101000951',
        'mrp': 299.99,
      }: 10,
    };

    await _printerService.previewBarcodes(
      context,
      productsWithQuantities,
      layoutMode: LayoutMode.grid,
      gridColumns: 2,
      gridRows: 7,
    );
  }

  /// Example 4: Custom grid dimensions (3x5 grid = 15 per page)
  Future<void> printCustomGrid(BuildContext context) async {
    final productsWithQuantities = {
      {
        'id': 'PROD001',
        'name': 'Sample Product',
        'barcode': '2010101000951',
        'mrp': 199.99,
      }: 15,
    };

    await _printerService.printBarcodes(
      context,
      productsWithQuantities,
      layoutMode: LayoutMode.grid,
      gridColumns: 3, // 3 columns
      gridRows: 5,    // 5 rows
    );
  }
}

/// Example widget showing how to integrate into your Flutter app
class BarcodeSettingsDialog extends StatefulWidget {
  final Map<Map<String, dynamic>, int> productsWithQuantities;

  const BarcodeSettingsDialog({
    Key? key,
    required this.productsWithQuantities,
  }) : super(key: key);

  @override
  State<BarcodeSettingsDialog> createState() => _BarcodeSettingsDialogState();
}

class _BarcodeSettingsDialogState extends State<BarcodeSettingsDialog> {
  final BarcodePrinterService _printerService = BarcodePrinterService();
  
  LayoutMode _selectedLayout = 
      LayoutMode.grid;
  int _gridColumns = 2;
  int _gridRows = 7;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Barcode Print Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Layout Mode:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioListTile<LayoutMode>(
              title: const Text('Grid Layout (Multiple per page)'),
              subtitle: const Text('Compact layout like sticker sheets'),
              value: LayoutMode.grid,
              groupValue: _selectedLayout,
              onChanged: (value) {
                setState(() {
                  _selectedLayout = value!;
                });
              },
            ),
            RadioListTile<LayoutMode>(
              title: const Text('2 Per Page Layout'),
              subtitle: const Text('Larger barcodes with more details'),
              value: LayoutMode.twoPerPage,
              groupValue: _selectedLayout,
              onChanged: (value) {
                setState(() {
                  _selectedLayout = value!;
                });
              },
            ),
            
            if (_selectedLayout == LayoutMode.grid) ...[
              const SizedBox(height: 16),
              const Text(
                'Grid Settings:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Columns: $_gridColumns'),
                        Slider(
                          value: _gridColumns.toDouble(),
                          min: 1,
                          max: 4,
                          divisions: 3,
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
                        Text('Rows: $_gridRows'),
                        Slider(
                          value: _gridRows.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
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
              Text(
                'Barcodes per page: ${_gridColumns * _gridRows}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await _printerService.previewBarcodes(
              context,
              widget.productsWithQuantities,
              layoutMode: _selectedLayout,
              gridColumns: _gridColumns,
              gridRows: _gridRows,
            );
          },
          icon: const Icon(Icons.visibility),
          label: const Text('Preview'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await _printerService.printBarcodes(
              context,
              widget.productsWithQuantities,
              layoutMode: _selectedLayout,
              gridColumns: _gridColumns,
              gridRows: _gridRows,
            );
          },
          icon: const Icon(Icons.print),
          label: const Text('Print'),
        ),
      ],
    );
  }
}

/// Example: How to show the dialog from your app
void showBarcodePrintDialog(
  BuildContext context,
  Map<Map<String, dynamic>, int> productsWithQuantities,
) {
  showDialog(
    context: context,
    builder: (context) => BarcodeSettingsDialog(
      productsWithQuantities: productsWithQuantities,
    ),
  );
}