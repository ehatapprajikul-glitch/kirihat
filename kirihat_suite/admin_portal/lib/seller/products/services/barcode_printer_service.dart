import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode_widget/barcode_widget.dart' as barcode_widget;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';

/// Layout mode enum for barcode printing
enum LayoutMode {
  grid,        // Multiple barcodes in grid (like the uploaded image)
  twoPerPage,  // Original 2-per-page layout
}

/// Enhanced service to generate and print barcode labels for products
/// Supports multiple layout modes:
/// - Grid layout (multiple barcodes per page in rows/columns)
/// - 2-per-page layout (original format)
class BarcodePrinterService {
  /// Paper dimensions in inches
  static const double paperWidthInches = 4.0;
  static const double paperHeightInches = 6.0;
  
  /// Barcode dimensions in inches for 2-per-page layout
  static const double barcodeWidthInches = 2.0;
  static const double barcodeHeightInches = 1.0;
  
  /// Convert inches to points (1 inch = 72 points)
  static const double inchToPoints = 72.0;
  
  /// Page format for 4x6 paper
  static final PdfPageFormat pageFormat = PdfPageFormat(
    paperWidthInches * inchToPoints,
    paperHeightInches * inchToPoints,
    marginAll: 0.25 * inchToPoints, // 0.25 inch margin
  );

  /// Generate barcode PDF with selectable layout mode
  /// 
  /// [productsWithQuantities] - Map of product data to number of labels needed
  /// [layoutMode] - Choose between grid or 2-per-page layout
  /// [gridColumns] - Number of columns for grid layout (default: 2)
  /// [gridRows] - Number of rows for grid layout (default: 7)
  /// Returns PDF bytes ready for printing
  Future<Uint8List> generateBarcodesPdf(
    Map<Map<String, dynamic>, int> productsWithQuantities, {
    LayoutMode layoutMode = LayoutMode.grid,
    int gridColumns = 2,
    int gridRows = 7,
  }) async {
    final pdf = pw.Document();
    
    // Flatten products into individual barcode entries
    final List<Map<String, dynamic>> barcodeEntries = [];
    productsWithQuantities.forEach((product, quantity) {
      for (int i = 0; i < quantity; i++) {
        barcodeEntries.add(product);
      }
    });
    
    if (barcodeEntries.isEmpty) {
      throw Exception('No products selected for barcode printing');
    }
    
    switch (layoutMode) {
      case LayoutMode.grid:
        _generateGridLayout(pdf, barcodeEntries, gridColumns, gridRows);
        break;
      case LayoutMode.twoPerPage:
        _generateTwoPerPageLayout(pdf, barcodeEntries);
        break;
    }
    
    return pdf.save();
  }

  /// Generate grid layout (multiple barcodes per page)
  void _generateGridLayout(
    pw.Document pdf,
    List<Map<String, dynamic>> barcodeEntries,
    int columns,
    int rows,
  ) {
    final int barcodesPerPage = columns * rows;
    final int totalPages = (barcodeEntries.length / barcodesPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final int startIndex = pageIndex * barcodesPerPage;
      final int endIndex = (startIndex + barcodesPerPage).clamp(0, barcodeEntries.length);
      final List<Map<String, dynamic>> pageEntries = 
          barcodeEntries.sublist(startIndex, endIndex);
      
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return _buildGridPage(pageEntries, columns, rows);
          },
        ),
      );
    }
  }

  /// Build a grid page with multiple barcodes
  pw.Widget _buildGridPage(
    List<Map<String, dynamic>> entries,
    int columns,
    int rows,
  ) {
    // Calculate available space
    final double availableWidth = (paperWidthInches - 0.5) * inchToPoints; // Subtract margins
    final double availableHeight = (paperHeightInches - 0.5) * inchToPoints;
    
    // Calculate cell dimensions
    final double cellWidth = availableWidth / columns;
    final double cellHeight = availableHeight / rows;
    
    // Build rows
    final List<pw.Widget> rowWidgets = [];
    
    for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
      final List<pw.Widget> cellWidgets = [];
      
      for (int colIndex = 0; colIndex < columns; colIndex++) {
        final int entryIndex = rowIndex * columns + colIndex;
        
        if (entryIndex < entries.length) {
          cellWidgets.add(
            pw.Container(
              width: cellWidth,
              height: cellHeight,
              padding: const pw.EdgeInsets.all(4),
              child: _buildCompactBarcodeLabel(
                entries[entryIndex],
                cellWidth - 8,
                cellHeight - 8,
              ),
            ),
          );
        } else {
          // Empty cell
          cellWidgets.add(
            pw.Container(
              width: cellWidth,
              height: cellHeight,
            ),
          );
        }
      }
      
      rowWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: cellWidgets,
        ),
      );
    }
    
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: rowWidgets,
    );
  }

  /// Build a compact barcode label for grid layout
  pw.Widget _buildCompactBarcodeLabel(
    Map<String, dynamic> product,
    double maxWidth,
    double maxHeight,
  ) {
    final String barcodeData = product['barcode'] ?? product['id'] ?? '';
    
    // Barcode takes most of the vertical space
    final double barcodeHeight = maxHeight * 0.7;
    
    return pw.Container(
      width: maxWidth,
      height: maxHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Barcode
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: pw.BarcodeWidget(
                  data: barcodeData,
                  barcode: pw.Barcode.code128(),
                  width: maxWidth - 4,
                  height: barcodeHeight - 4,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate original 2-per-page layout
  void _generateTwoPerPageLayout(
    pw.Document pdf,
    List<Map<String, dynamic>> barcodeEntries,
  ) {
    // Generate pages - 2 barcodes per page (top and bottom)
    for (int i = 0; i < barcodeEntries.length; i += 2) {
      final product1 = barcodeEntries[i];
      final product2 = i + 1 < barcodeEntries.length ? barcodeEntries[i + 1] : null;
      
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _buildBarcodeLabel(product1),
                if (product2 != null) ...[
                  pw.SizedBox(height: 20),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 20),
                  _buildBarcodeLabel(product2),
                ],
              ],
            );
          },
        ),
      );
    }
  }

  /// Build a standard barcode label widget (for 2-per-page layout)
  pw.Widget _buildBarcodeLabel(Map<String, dynamic> product) {
    final String productName = product['name'] ?? 'Unknown Product';
    final String productId = product['id'] ?? '';
    final double price = (product['mrp'] ?? product['selling_price'] ?? 0).toDouble();
    final String barcodeData = product['barcode'] ?? productId;
    
    return pw.Container(
      width: barcodeWidthInches * inchToPoints,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Product Name
          pw.Text(
            productName,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
          ),
          pw.SizedBox(height: 8),
          
          // Barcode
          pw.Container(
            width: barcodeWidthInches * inchToPoints,
            height: barcodeHeightInches * inchToPoints,
            child: pw.BarcodeWidget(
              data: barcodeData,
              barcode: pw.Barcode.code128(),
              width: barcodeWidthInches * inchToPoints,
              height: barcodeHeightInches * inchToPoints,
              drawText: true,
              textStyle: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 8),
          
          // Price
          pw.Text(
            'MRP: ₹${price.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          
          // Product ID (small text)
          pw.SizedBox(height: 4),
          pw.Text(
            'ID: $productId',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  /// Print barcodes directly with layout options
  Future<void> printBarcodes(
    BuildContext context,
    Map<Map<String, dynamic>, int> productsWithQuantities, {
    LayoutMode layoutMode = LayoutMode.grid,
    int gridColumns = 2,
    int gridRows = 7,
  }) async {
    try {
      final pdfBytes = await generateBarcodesPdf(
        productsWithQuantities,
        layoutMode: layoutMode,
        gridColumns: gridColumns,
        gridRows: gridRows,
      );
      
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'product_barcodes_${DateTime.now().millisecondsSinceEpoch}.pdf',
        format: pageFormat,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing barcodes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  /// Preview barcodes before printing with layout options
  Future<void> previewBarcodes(
    BuildContext context,
    Map<Map<String, dynamic>, int> productsWithQuantities, {
    LayoutMode layoutMode = LayoutMode.grid,
    int gridColumns = 2,
    int gridRows = 7,
  }) async {
    try {
      final pdfBytes = await generateBarcodesPdf(
        productsWithQuantities,
        layoutMode: layoutMode,
        gridColumns: gridColumns,
        gridRows: gridRows,
      );
      
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'product_barcodes_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating barcodes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }
}