import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AccountDeletionsScreen extends StatefulWidget {
  const AccountDeletionsScreen({super.key});

  @override
  State<AccountDeletionsScreen> createState() => _AccountDeletionsScreenState();
}

class _AccountDeletionsScreenState extends State<AccountDeletionsScreen> {
  String _selectedFilter = 'all'; // all, customer, rider
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_off, color: Colors.red[700], size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Deletions',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Monitor why users are leaving the platform',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Filter Chips
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Customers', 'customer'),
                const SizedBox(width: 8),
                _buildFilterChip('Riders', 'rider'),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_satisfied_alt, size: 80, color: Colors.green[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No account deletions yet!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'All your users are happy.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                final docs = snapshot.data!.docs;
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      _buildStatsRow(docs),
                      const SizedBox(height: 24),
                      
                      // Deletion List
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 2, child: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(flex: 1, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 50),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            
                            // Rows
                            ...docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildDeletionRow(data, doc.id);
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    var query = FirebaseFirestore.instance
        .collection('account_deletions')
        .orderBy('deleted_at', descending: true);
    
    if (_selectedFilter != 'all') {
      query = query.where('user_type', isEqualTo: _selectedFilter) as Query<Map<String, dynamic>>;
    }
    
    return query.snapshots();
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: Colors.red[100],
      checkmarkColor: Colors.red[700],
      labelStyle: TextStyle(
        color: isSelected ? Colors.red[900] : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatsRow(List<QueryDocumentSnapshot> docs) {
    final customerCount = docs.where((d) => (d.data() as Map)['user_type'] == 'customer').length;
    final riderCount = docs.where((d) => (d.data() as Map)['user_type'] == 'rider').length;
    
    // Count reasons
    final reasonCounts = <String, int>{};
    for (var doc in docs) {
      final reason = (doc.data() as Map)['reason'] ?? 'Unknown';
      reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
    }
    final topReason = reasonCounts.entries.isNotEmpty
        ? reasonCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'N/A';
    
    return Row(
      children: [
        _buildStatCard('Total Deletions', docs.length.toString(), Icons.delete_forever, Colors.red),
        const SizedBox(width: 16),
        _buildStatCard('Customers', customerCount.toString(), Icons.person, Colors.blue),
        const SizedBox(width: 16),
        _buildStatCard('Riders', riderCount.toString(), Icons.delivery_dining, Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard('Top Reason', topReason, Icons.trending_up, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletionRow(Map<String, dynamic> data, String docId) {
    final userType = data['user_type'] ?? 'unknown';
    final reason = data['reason'] ?? 'Not specified';
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final deletedAt = data['deleted_at'] as Timestamp?;
    final dateStr = deletedAt != null
        ? DateFormat('MMM dd, yyyy - hh:mm a').format(deletedAt.toDate())
        : 'Unknown';
    
    return InkWell(
      onTap: () => _showDetailDialog(data),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email.isNotEmpty ? email : phone, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (phone.isNotEmpty && email.isNotEmpty)
                    Text(phone, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: userType == 'customer' ? Colors.blue[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  userType.toString().toUpperCase(),
                  style: TextStyle(
                    color: userType == 'customer' ? Colors.blue[700] : Colors.orange[700],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(reason, style: TextStyle(color: Colors.grey[700])),
            ),
            Expanded(
              flex: 2,
              child: Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.grey),
              onPressed: () => _showDetailDialog(data),
              tooltip: 'View Details',
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> data) {
    final issues = (data['issues'] as List<dynamic>?)?.cast<String>() ?? [];
    final feedback = data['feedback'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('Deletion Details'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('User Type', (data['user_type'] ?? '').toString().toUpperCase()),
                _buildDetailRow('Email', data['email'] ?? 'N/A'),
                _buildDetailRow('Phone', data['phone'] ?? 'N/A'),
                _buildDetailRow('Reason', data['reason'] ?? 'Not specified'),
                const SizedBox(height: 16),
                
                if (issues.isNotEmpty) ...[
                  const Text('Issues Reported:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: issues.map((issue) => Chip(
                      label: Text(issue, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.red[50],
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (feedback.isNotEmpty) ...[
                  const Text('Additional Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(feedback, style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
