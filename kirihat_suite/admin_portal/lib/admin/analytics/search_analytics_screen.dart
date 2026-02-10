import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;

class SearchAnalyticsScreen extends StatefulWidget {
  const SearchAnalyticsScreen({super.key});

  @override
  State<SearchAnalyticsScreen> createState() => _SearchAnalyticsScreenState();
}

class _SearchAnalyticsScreenState extends State<SearchAnalyticsScreen> {
  final int _rowsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  Future<void> _exportToCSV(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    // CSV Header
    StringBuffer csv = StringBuffer();
    csv.writeln('Query,Date,Time,User ID,Vendor ID,Platform');

    // CSV Rows
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      final dateTime = timestamp?.toDate() ?? DateTime.now();
      
      String escapeCsvField(String? field) {
        if (field == null) return '';
        if (field.contains(',') || field.contains('"') || field.contains('\n')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }

      csv.writeln(
        '${escapeCsvField(data['query'])},'
        '${DateFormat('yyyy-MM-dd').format(dateTime)},'
        '${DateFormat('HH:mm:ss').format(dateTime)},'
        '${escapeCsvField(data['user_id'])},'
        '${escapeCsvField(data['vendor_id'])},'
        '${escapeCsvField(data['platform'])}'
      );
    }

    // Trigger Download
    final bytes = utf8.encode(csv.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'search_analytics_export_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Exported ${docs.length} rows to CSV')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Search Analytics', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('search_analytics').limit(1000).snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    '$count searches logged', 
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('search_analytics')
            .orderBy('timestamp', descending: true)
            .limit(500) // Limit to last 500 for performance
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No search history found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Export
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Search History (Last 500)', 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _exportToCSV(docs),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),

                // Data Table
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: PaginatedDataTable(
                    header: const Text('Search Logs'),
                    rowsPerPage: _rowsPerPage,
                    columns: const [
                      DataColumn(label: Text('Query')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Vendor')),
                    ],
                    source: _SearchDataSource(docs),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchDataSource extends DataTableSource {
  final List<QueryDocumentSnapshot> _docs;

  _SearchDataSource(this._docs);

  @override
  DataRow? getRow(int index) {
    if (index >= _docs.length) return null;
    final data = _docs[index].data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateTime = timestamp?.toDate() ?? DateTime.now();

    return DataRow(
      cells: [
        DataCell(Text(
          data['query'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500),
        )),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('MMM d, yyyy').format(dateTime)),
            Text(DateFormat('h:mm a').format(dateTime), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        )),
        DataCell(_UserDetailCell(uid: data['user_id'])),
        DataCell(Text(
          _truncateId(data['vendor_id']),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        )),
      ],
    );
  }



  String _truncateId(String? id) {
    if (id == null) return '-';
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => _docs.length;
  @override
  int get selectedRowCount => 0;
}

class _UserDetailCell extends StatelessWidget {
  final String? uid;

  const _UserDetailCell({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null || uid!.isEmpty) return const Text('-');

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 12, 
            height: 12, 
            child: CircularProgressIndicator(strokeWidth: 2)
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text(
            _truncateId(uid),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? data['displayName'] ?? 'Unknown';
        
        // Smart phone extraction with fallback
        var phone = data['phone'] ?? data['phone_number'] ?? data['phoneNumber'];
        if (phone == null && data['current_address'] != null && data['current_address'] is Map) {
            phone = data['current_address']['phone'];
        }
        final displayPhone = (phone ?? '').toString();
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                if (displayPhone.isNotEmpty && displayPhone != 'null')
                  Text(displayPhone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  _truncateId(uid),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Colors.blueGrey),
              tooltip: 'Copy Details',
              onPressed: () {
                final text = 'Name: $name\nPhone: $displayPhone\nUID: $uid';
                html.window.navigator.clipboard?.writeText(text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User details copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _truncateId(String? id) {
    if (id == null) return '-';
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }
}
