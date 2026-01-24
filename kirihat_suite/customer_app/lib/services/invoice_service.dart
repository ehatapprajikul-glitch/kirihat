import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:kirihat_core/utils/currency_helper.dart';

class InvoiceService {
  static Future<void> generateInvoice(Map<String, dynamic> orderData) async {
    final pdf = pw.Document();
    
    // Load Fonts
    final boldFont = await PdfGoogleFonts.interBold();
    final regularFont = await PdfGoogleFonts.interRegular();
    final lightFont = await PdfGoogleFonts.interLight();
    
    // Load Logo
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
      debugPrint('✅ Logo loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading logo: $e');
    }
    
    debugPrint('📝 Generating Invoice for Data: $orderData');
    
    // Extract Order Data
    String orderId = orderData['order_id'] ?? 'KIRI-UNKNOWN';
    debugPrint('🆔 Order ID extracted: $orderId');
    DateTime orderDate = (orderData['created_at'] != null) 
        ? (orderData['created_at'] as dynamic).toDate() 
        : DateTime.now();
    List items = orderData['items'] ?? [];
    
    // Financial Details
    double productTotal = (orderData['product_total'] ?? 0).toDouble();
    double deliveryFee = (orderData['delivery_fee'] ?? 0).toDouble();
    double taxAmount = (orderData['tax_amount'] ?? 0).toDouble();
    double platformFee = (orderData['platform_fee'] ?? 0).toDouble();
    double lowCartFee = (orderData['low_cart_fee'] ?? 0).toDouble();
    double totalAmount = (orderData['total_amount'] ?? 0).toDouble();
    
    // Address Details
    Map<String, dynamic> deliveryAddress = orderData['delivery_address'] ?? {};
    String customerName = deliveryAddress['name'] ?? 'Customer';
    String customerPhone = deliveryAddress['phone'] ?? '';
    List<String> addressParts = [
      deliveryAddress['house_no']?.toString(),
      deliveryAddress['street']?.toString(),
      deliveryAddress['landmark']?.toString(),
      deliveryAddress['city']?.toString(),
      deliveryAddress['state']?.toString(),
    ].where((s) => s != null && s.trim().isNotEmpty && s != 'null').cast<String>().toList();
    String fullAddress = addressParts.join(', ');
    if (deliveryAddress['pincode'] != null && deliveryAddress['pincode'].toString().isNotEmpty) {
      fullAddress += ' - ${deliveryAddress['pincode']}';
    }
    
    // Vendor Details (Darkstore)
    String vendorId = orderData['vendor_id'] ?? '';
    String vendorName = orderData['vendor_name'] ?? 'KiriHat Store';
    String vendorCity = orderData['vendor_city'] ?? '';
    String vendorState = orderData['vendor_state'] ?? '';
    
    // Brand Color
    final primaryGreen = PdfColor.fromHex('#0D9759');
    final lightGreen = PdfColor.fromHex('#E8F5E9');
    final darkGrey = PdfColor.fromHex('#1C1C1C');
    final mediumGrey = PdfColor.fromHex('#757575');
    final lightGrey = PdfColor.fromHex('#F5F5F5');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return [
            // HEADER SECTION WITH BRAND COLOR
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [primaryGreen, PdfColor.fromHex('#0A7A44')],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo and Brand Name
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logo != null)
                        pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Image(logo, width: 50, height: 50),
                        )
                      else
                        // Brand Name with Icon Fallback
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 40,
                              height: 40,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  'K',
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 24,
                                    color: primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Text(
                              'KiriHat',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 32,
                                color: PdfColors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      if (logo != null)
                         pw.Text(
                              'KiriHat',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 24,
                                color: PdfColors.white,
                                letterSpacing: 1,
                              ),
                            ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Quick Commerce at Your Doorstep',
                        style: pw.TextStyle(
                          font: lightFont,
                          fontSize: 10,
                          color: PdfColors.white.shade(0.9),
                        ),
                      ),
                    ],
                  ),
                  
                  // Invoice Title
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 36,
                          color: PdfColors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '#$orderId',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 12,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        DateFormat('dd MMMM yyyy').format(orderDate),
                        style: pw.TextStyle(
                          font: lightFont,
                          fontSize: 11,
                          color: PdfColors.white.shade(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // ADDRESS SECTION
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer Details
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: lightGrey,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DELIVERY ADDRESS',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: mediumGrey,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            customerName,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14,
                              color: darkGrey,
                            ),
                          ),
                          if (customerPhone.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              customerPhone,
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 11,
                                color: mediumGrey,
                              ),
                            ),
                          ],
                          pw.SizedBox(height: 8),
                          pw.Text(
                            fullAddress,
                            style: pw.TextStyle(
                              font: regularFont,
                              fontSize: 10,
                              color: darkGrey,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  pw.SizedBox(width: 20),
                  
                  // Vendor Details (Darkstore)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: lightGreen,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: primaryGreen.shade(0.3)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'FULFILLED BY',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: primaryGreen,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            vendorName,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 14,
                              color: darkGrey,
                            ),
                          ),
                          if (vendorCity.isNotEmpty || vendorState.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              [vendorCity, vendorState]
                                  .where((s) => s.isNotEmpty)
                                  .join(', '),
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 10,
                                color: darkGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // ITEMS TABLE
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ORDER ITEMS',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 12,
                      color: darkGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  
                  // Table Header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: pw.BoxDecoration(
                      color: primaryGreen,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            'ITEM',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            'QTY',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            'PRICE',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            'TOTAL',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Table Rows
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: lightGrey),
                      borderRadius: const pw.BorderRadius.only(
                        bottomLeft: pw.Radius.circular(8),
                        bottomRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Column(
                      children: items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isLast = index == items.length - 1;
                        
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: pw.BoxDecoration(
                            color: index.isEven ? PdfColors.white : lightGrey,
                            borderRadius: isLast ? const pw.BorderRadius.only(
                              bottomLeft: pw.Radius.circular(8),
                              bottomRight: pw.Radius.circular(8),
                            ) : null,
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text(
                                  item['name'] ?? 'Item',
                                  style: pw.TextStyle(
                                    font: regularFont,
                                    fontSize: 10,
                                    color: darkGrey,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  'x${item['quantity']}',
                                  style: pw.TextStyle(
                                    font: regularFont,
                                    fontSize: 10,
                                    color: mediumGrey,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  CurrencyHelper.format(item['price']),
                                  style: pw.TextStyle(
                                    font: regularFont,
                                    fontSize: 10,
                                    color: darkGrey,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  CurrencyHelper.format(item['price'] * item['quantity']),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 10,
                                    color: darkGrey,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // BILLING SUMMARY
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.SizedBox()),
                  pw.Container(
                    width: 280,
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: lightGrey,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        _buildBillRow('Subtotal', productTotal, regularFont, mediumGrey, darkGrey),
                        if (deliveryFee > 0) ...[
                          pw.SizedBox(height: 8),
                          _buildBillRow('Delivery Fee', deliveryFee, regularFont, mediumGrey, darkGrey),
                        ],
                        if (taxAmount > 0) ...[
                          pw.SizedBox(height: 8),
                          _buildBillRow('Tax (GST)', taxAmount, regularFont, mediumGrey, darkGrey),
                        ],
                        if (platformFee > 0) ...[
                          pw.SizedBox(height: 8),
                          _buildBillRow('Platform Fee', platformFee, regularFont, mediumGrey, darkGrey),
                        ],
                        if (lowCartFee > 0) ...[
                          pw.SizedBox(height: 8),
                          _buildBillRow('Small Order Fee', lowCartFee, regularFont, mediumGrey, darkGrey),
                        ],
                        pw.SizedBox(height: 12),
                        pw.Divider(color: mediumGrey),
                        pw.SizedBox(height: 12),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL AMOUNT',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 12,
                                color: darkGrey,
                              ),
                            ),
                            pw.Text(
                              CurrencyHelper.format(totalAmount),
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 16,
                                color: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 40),
            
            // FOOTER
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(30),
              margin: const pw.EdgeInsets.only(top: 20),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                border: pw.Border(
                  top: pw.BorderSide(color: primaryGreen, width: 2),
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'CUSTOMER SUPPORT',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 11,
                      color: darkGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _buildContactItem('Phone:', '+91 123 456 7890', regularFont, mediumGrey),
                      pw.SizedBox(width: 30),
                      _buildContactItem('Email:', 'support@kirihat.com', regularFont, mediumGrey),
                      pw.SizedBox(width: 30),
                      _buildContactItem('Web:', 'www.kirihat.com', regularFont, mediumGrey),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: lightGreen,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      'Thank you for choosing KiriHat!',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'This is a computer-generated invoice and does not require a signature.',
                    style: pw.TextStyle(
                      font: lightFont,
                      fontSize: 8,
                      color: mediumGrey,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  
  // Helper method for billing rows
  static pw.Widget _buildBillRow(
    String label,
    double amount,
    pw.Font font,
    PdfColor labelColor,
    PdfColor amountColor,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: labelColor,
          ),
        ),
        pw.Text(
          CurrencyHelper.format(amount),
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: amountColor,
          ),
        ),
      ],
    );
  }
  
  // Helper method for contact items
  static pw.Widget _buildContactItem(
    String icon,
    String text,
    pw.Font font,
    PdfColor color,
  ) {
    return pw.Row(
      children: [
        pw.Text(
          icon,
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            color: color,
          ),
        ),
      ],
    );
  }
}