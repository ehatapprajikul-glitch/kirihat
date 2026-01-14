import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:kirihat_core/models/seller_model.dart';

class SellerReportService {
  
  /// Generate and print/share a PDF Report
  Future<void> generatePdfReport({
    required SellerModel seller,
    required List<Map<String, dynamic>> orders,
    required DateTime startDate,
    required DateTime endDate,
    required double totalRevenue,
    required double platformFees,
    required double netEarnings,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildHeader(seller, startDate, endDate),
          pw.SizedBox(height: 20),
          _buildFinancialSummary(totalRevenue, platformFees, netEarnings),
          pw.SizedBox(height: 20),
          pw.Text('Transaction History', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildOrderTable(orders),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Sales_Report_${DateFormat('ddMMMyy').format(startDate)}-${DateFormat('ddMMMyy').format(endDate)}',
    );
  }

  pw.Widget _buildHeader(SellerModel seller, DateTime start, DateTime end) {
    final formatter = DateFormat('MMM dd, yyyy');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SALES REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated On', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text(DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Seller Details', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(seller.businessName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('Owner: ${seller.ownerName}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('ID: ${seller.id}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.Expanded(
               child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Report Period', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('${formatter.format(start)} - ${formatter.format(end)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFinancialSummary(double gross, double fees, double net) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Gross Sales', gross, PdfColors.black),
          _buildSummaryItem('Platform Fees', fees, PdfColors.orange700),
          _buildSummaryItem('Net Earnings', net, PdfColors.green700, isBold: true),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, double amount, PdfColor color, {bool isBold = false}) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          'INR ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildOrderTable(List<Map<String, dynamic>> orders) {
    final headers = ['Date', 'Order ID', 'Items', 'Status', 'Amount'];
    
    final data = orders.map((order) {
      final date = (order['created_at'] as DateTime?) ?? DateTime.now();
      return [
        DateFormat('MMM dd').format(date),
        '#${order['order_id'] ?? 'N/A'}',
        '${(order['items'] as List?)?.length ?? 0} items',
        order['status'] ?? '-',
        '${(order['total'] as num).toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Text('This is a system generated report.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        pw.Text('Kirihat Platform', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    );
  }
}
