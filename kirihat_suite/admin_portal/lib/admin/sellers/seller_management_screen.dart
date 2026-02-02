import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerManagementScreen extends StatefulWidget {
  const SellerManagementScreen({super.key});

  @override
  State<SellerManagementScreen> createState() => _SellerManagementScreenState();
}

class _SellerManagementScreenState extends State<SellerManagementScreen> {
  final _sellerService = SellerService();
  String _selectedFilter = 'all'; // all, pending, active, rejected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Management'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _selectedFilter,
              dropdownColor: Colors.white,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Sellers')),
                DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedFilter = value);
                }
              },
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<SellerModel>>(
        stream: _selectedFilter == 'all'
            ? _sellerService.getAllSellers()
            : _sellerService.getSellersByStatus(_selectedFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'pending'
                        ? 'No pending seller requests'
                        : 'No sellers found',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final sellers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sellers.length,
            itemBuilder: (context, index) {
              final seller = sellers[index];
              return _buildSellerCard(seller);
            },
          );
        },
      ),
    );
  }

  Widget _buildSellerCard(SellerModel seller) {
    Color statusColor;
    IconData statusIcon;
    
    switch (seller.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'suspended':
        statusColor = Colors.grey;
        statusIcon = Icons.pause_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D9759).withOpacity(0.1),
          child: const Icon(Icons.store, color: Color(0xFF0D9759)),
        ),
        title: Text(
          seller.businessName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Owner: ${seller.ownerName}'),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  seller.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.phone, 'Phone', seller.phone),
                _buildInfoRow(Icons.email, 'Email', seller.email),
                _buildInfoRow(Icons.location_on, 'Location', '${seller.city}, ${seller.state}'),
                _buildInfoRow(Icons.pin_drop, 'Pincode', seller.pincode),
                if (seller.gstNumber != null)
                  _buildInfoRow(Icons.receipt_long, 'GST', seller.gstNumber!),
                if (seller.panNumber != null)
                  _buildInfoRow(Icons.credit_card, 'PAN', seller.panNumber!),
                const Divider(height: 24),
                _buildDocumentsSection(seller), // New Documents Section
                _buildStatsRow(seller),
                const SizedBox(height: 16),
                _buildActionButtons(seller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(SellerModel seller) {
    if (seller.documents == null || seller.documents!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: seller.documents!.entries.map((entry) {
            // Determine icon and color based on file type or name
            IconData icon = Icons.description;
            if (entry.key.contains('gst')) icon = Icons.receipt;
            if (entry.key.contains('pan')) icon = Icons.credit_card;
            
            return ActionChip(
              avatar: Icon(icon, size: 16),
              label: Text(entry.key.toUpperCase()),
              onPressed: () => _launchUrl(entry.value),
              backgroundColor: Colors.blue.shade50,
            );
          }).toList(),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback or error handling
      debugPrint('Could not launch $url');
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(SellerModel seller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Products', '${seller.totalProducts}', Icons.inventory_2),
        _buildStatItem('Active', '${seller.activeProducts}', Icons.check_circle_outline),
        _buildStatItem('Sales', CurrencyHelper.format(seller.totalSales), Icons.trending_up),
        _buildStatItem('Rating', '${seller.rating.toStringAsFixed(1)}', Icons.star),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0D9759)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SellerModel seller) {
    if (seller.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approveSeller(seller),
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectSeller(seller),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      );
    } else if (seller.status == 'active') {
      return OutlinedButton.icon(
        onPressed: () => _suspendSeller(seller),
        icon: const Icon(Icons.pause),
        label: const Text('Suspend'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Future<void> _approveSeller(SellerModel seller) async {
    final adminUserId = 'admin_uid'; // TODO: Get from current user
    final success = await _sellerService.approveSeller(seller.id, adminUserId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved ${seller.businessName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectSeller(SellerModel seller) async {
    // Show dialog to get rejection reason
    final TextEditingController reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Seller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject ${seller.businessName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminUserId = 'admin_uid'; // TODO: Get from current user
      final success = await _sellerService.rejectSeller(
        seller.id,
        adminUserId,
        reasonController.text,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${seller.businessName}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _suspendSeller(SellerModel seller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Seller'),
        content: Text('Suspend ${seller.businessName}? They will not be able to list or sell products.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _sellerService.updateSeller(seller.id, {'status': 'suspended'});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Suspended ${seller.businessName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
