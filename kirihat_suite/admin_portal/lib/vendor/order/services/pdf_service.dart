import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:kirihat_core/utils/currency_helper.dart';

class PDFService {
  // Generate 4x6 thermal shipping label (black & white, optimized)
  Future<void> generateShippingLabel(OrderModel order) async {
    try {
      debugPrint('PDF INFO: Generating label for ${order.orderId}');
      debugPrint('PDF INFO: Customer: ${order.customerName}');
      debugPrint('PDF INFO: Address: ${order.deliveryAddress.fullAddress}');
      debugPrint('PDF INFO: Vendor: ${order.vendorName}');
      
      final pdf = pw.Document();
    
    // Load minimal fonts (Roboto only, no icons needed for thermal)
    final font = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    
    // 4x6 inch format for thermal printers
    final labelFormat = PdfPageFormat(
      10.16 * PdfPageFormat.cm,  // 4 inches
      15.24 * PdfPageFormat.cm,  // 6 inches
      marginAll: 0.3 * PdfPageFormat.cm,
    );
    
    // PAGE 1: VENDOR COPY
    pdf.addPage(
      pw.MultiPage(
        pageFormat: labelFormat,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: bold,
        ),
        header: (context) => _buildLabelHeader(order, 'VENDOR COPY'),
        build: (context) => [_buildVendorSection(order)],
      ),
    );

    // PAGE 2: RIDER COPY
    pdf.addPage(
      pw.MultiPage(
        pageFormat: labelFormat,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: bold,
        ),
        header: (context) => _buildLabelHeader(order, 'RIDER COPY'),
        build: (context) => [
          _buildRiderSection(order),
          if (order.priority != null) ...[
            pw.SizedBox(height: 10),
            _buildPriorityBadge(order.priority!),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'label_${order.orderId}.pdf',
    );
    } catch (e) {
      debugPrint('Error generating shipping label: $e');
    }
  }

  // Generate bulk shipping labels (one per page/document)
  Future<void> generateBulkShippingLabels(List<OrderModel> orders) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      
      final labelFormat = PdfPageFormat(
        10.16 * PdfPageFormat.cm,
        15.24 * PdfPageFormat.cm,
        marginAll: 0.3 * PdfPageFormat.cm,
      );

      for (var order in orders) {
        // VENDOR PAGE
        pdf.addPage(
          pw.MultiPage(
            pageFormat: labelFormat,
            theme: pw.ThemeData.withFont(base: font, bold: bold),
            header: (context) => _buildLabelHeader(order, 'VENDOR COPY'),
            build: (context) => [_buildVendorSection(order)],
          ),
        );
        // RIDER PAGE
        pdf.addPage(
          pw.MultiPage(
            pageFormat: labelFormat,
            theme: pw.ThemeData.withFont(base: font, bold: bold),
            header: (context) => _buildLabelHeader(order, 'RIDER COPY'),
            build: (context) => [
              _buildRiderSection(order),
              if (order.priority != null) ...[
                pw.SizedBox(height: 10),
                _buildPriorityBadge(order.priority!),
              ],
            ],
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'bulk_labels_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('Error generating bulk shipping labels: $e');
    }
  }

  // Mask phone number: 9876543210 -> 9876xxxx10
  String _maskPhoneNumber(String phone) {
    if (phone.length >= 10) {
      final start = phone.substring(0, 4);
      final end = phone.substring(phone.length - 2);
      return '$start${'x' * (phone.length - 6)}$end';
    }
    return phone;
  }

  // Load logo from assets
  Future<pw.MemoryImage> _loadLogo() async {
    final ByteData data = await rootBundle.load('assets/logo.png');
    final Uint8List bytes = data.buffer.asUint8List();
    return pw.MemoryImage(bytes);
  }

  // Header section with Order Barcode (shared across pages)
  pw.Widget _buildLabelHeader(OrderModel order, String copyType) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ORDER: ${order.orderId}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                copyType,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: order.orderId,
            height: 30,
            drawText: false,
          ),
          pw.Divider(thickness: 1, height: 10),
        ],
      ),
    );
  }

  // Priority Badge Helper
  pw.Widget _buildPriorityBadge(String priority) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 2),
        ),
        child: pw.Text(
          priority.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }


  // VENDOR SECTION: Product barcodes + quantities
  pw.Widget _buildVendorSection(OrderModel order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: const pw.BoxDecoration(
              color: PdfColors.white, // Strictly white
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VENDOR COPY',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.Text(
                  'ITEMS: ${order.itemCount}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 6),
          
          // Products with barcodes
          ...order.items.map((item) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Item name and quantity
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey800,
                      ),
                      child: pw.Text(
                        'QTY: ${item.quantity}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Barcode if available, otherwise show product ID
                pw.SizedBox(height: 4),
                if (item.barcode != null && item.barcode!.isNotEmpty)
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: item.barcode!,
                    height: 38,
                    drawText: true,
                    textStyle: const pw.TextStyle(fontSize: 8),
                  )
                else
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    child: pw.Text(
                      'Product ID: ${item.productId}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // RIDER SECTION: QR code + shipping info
  pw.Widget _buildRiderSection(OrderModel order) {
    debugPrint('PDF INFO: Building Rider Section for ${order.orderId}');
    final isCOD = order.paymentMethod.toUpperCase() == 'COD';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey800,
            ),
            child: pw.Text(
              'RIDER COPY - DELIVERY INSTRUCTIONS',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          
          pw.SizedBox(height: 8),
          
          // QR Code and Order Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // QR Code
              pw.Container(
                width: 85,
                height: 85,
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: order.orderId,
                ),
              ),
              
              pw.SizedBox(width: 8),
              
              // Order details
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SCAN TO DELIVER',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      order.orderId,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      DateFormat('dd/MM/yy HH:mm').format(order.createdAt),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 5),
                    
                    // Payment info - prominent for COD
                    if (isCOD)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.black,
                        ),
                        child: pw.Text(
                          'COLLECT: ${CurrencyHelper.format(order.totalAmount)}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      )
                    else
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 1.5),
                        ),
                        child: pw.Text(
                          'PREPAID ✓',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1, color: PdfColors.grey600),
          pw.SizedBox(height: 6),
          
          // Shipping To (Customer) - High Prominence
          pw.Container(
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
              color: PdfColors.white, // Strictly white
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DELIVER TO (CUSTOMER):',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  (order.customerName.isEmpty ? 'CUSTOMER NAME MISSING' : order.customerName).toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 13, // Increased size for prominence
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text('PH: ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      _maskPhoneNumber(order.customerPhone),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ADDRESS:',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  (order.deliveryAddress.fullAddress.isEmpty ? 'ADDRESS MISSING' : order.deliveryAddress.fullAddress).toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 11, // Increased size for prominence
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 6),
          
          // Shipping From (Vendor) - Compacted for better fit
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1), // Black border
              color: PdfColors.white,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FROM: ${(order.vendorName ?? 'Kiri Hat Vendor').toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 1,
                      ),
                      if (order.vendorAddress != null)
                        pw.Text(
                          'Addr: ${order.vendorAddress}',
                          style: const pw.TextStyle(fontSize: 7),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                        ),
                    ],
                  ),
                ),
                if (order.vendorPhone != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Text(
                      'Ph: ${_maskPhoneNumber(order.vendorPhone!)}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  // Remove old methods (logo loading, enhanced label, all colored sections)
  // Keep only invoice generation below

  // Generate invoice (keeping existing implementation)
  Future<void> generateInvoice(OrderModel order) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildInvoiceHeader(order),
          pw.SizedBox(height: 20),
          _buildInvoiceDetails(order),
          pw.SizedBox(height: 20),
          _buildItemsTable(order),
          pw.SizedBox(height: 20),
          _buildInvoiceTotal(order),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'invoice_${order.orderId}.pdf',
    );
  }

  // Build invoice header
  pw.Widget _buildInvoiceHeader(OrderModel order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.deepOrange,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Order #${order.orderId}'),
            pw.Text('Date: ${DateFormat('dd MMM yyyy').format(order.createdAt)}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Kiri Hat',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Vendor Invoice'),
          ],
        ),
      ],
    );
  }

  // Build invoice details
  pw.Widget _buildInvoiceDetails(OrderModel order) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  order.customerName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(order.customerPhone),
                pw.SizedBox(height: 4),
                pw.Text(
                  order.deliveryAddress.fullAddress,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PAYMENT INFO:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildInfoRow('Method', order.paymentMethod),
                _buildInfoRow('Status', order.paymentStatus),
                _buildInfoRow('Delivery', order.deliveryMode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Build items table
  pw.Widget _buildItemsTable(OrderModel order) {
    return pw.Table.fromTextArray(
      border: null,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: ['Item', 'Qty', 'Price', 'Total'],
      data: order.items.map((item) => [
        item.name,
        item.quantity.toString(),
        CurrencyHelper.format(item.price),
        CurrencyHelper.format(item.total),
      ]).toList(),
    );
  }

  // Build invoice total
  pw.Widget _buildInvoiceTotal(OrderModel order) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.deepOrange50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          children: [
            _buildInfoRow('Subtotal', CurrencyHelper.format(order.totalAmount)),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  CurrencyHelper.format(order.totalAmount),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build info row
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
    