import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_coupon.dart';

class CouponManagement extends StatelessWidget {
  const CouponManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Discount Coupons',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showCreateCouponDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Coupon'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Coupons List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('coupons')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No coupons created yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showCreateCouponDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your First Coupon'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildCouponCard(context, doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCouponCard(BuildContext context, String id, Map<String, dynamic> data) {
    String code = data['code'] ?? '';
    String type = data['type'] ?? 'general';
    String discountType = data['discount_type'] ?? 'percentage';
    num discountValue = data['discount_value'] ?? 0;
    bool isActive = data['is_active'] ?? true;
    int usedCount = data['used_count'] ?? 0;
    int? usageLimit = data['usage_limit'];
    
    Timestamp? validUntil = data['valid_until'];
    bool isExpired = false;
    if (validUntil != null) {
      isExpired = validUntil.toDate().isBefore(DateTime.now());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive && !isExpired ? const Color(0xFF0D9759) : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Coupon Icon & Code
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive && !isExpired
                      ? [const Color(0xFF0D9759), const Color(0xFF0D9759).withOpacity(0.7)]
                      : [Colors.grey, Colors.grey[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_offer, color: Colors.white, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    discountType == 'percentage' 
                        ? '${discountValue.toInt()}%' 
                        : '₹${discountValue.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // Coupon Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildTypeBadge(type),
                      const Spacer(),
                      if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EXPIRED',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'INACTIVE',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Used: $usedCount${usageLimit != null ? ' / $usageLimit' : ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      if (data['min_order_value'] != null) ...[
                        const SizedBox(width: 16),
                        Text(
                          'Min Order: ₹${data['min_order_value']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                      if (validUntil != null) ...[
                        const SizedBox(width: 16),
                        Text(
                          'Expires: ${_formatDate(validUntil)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(isActive ? Icons.block : Icons.check_circle),
                      const SizedBox(width: 12),
                      Text(isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editCoupon(context, id, data);
                } else if (value == 'toggle') {
                  _toggleCoupon(context, id, isActive);
                } else if (value == 'delete') {
                  _deleteCoupon(context, id, code);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color;
    String label;

    switch (type) {
      case 'new_user':
        color = Colors.blue;
        label = 'NEW USER';
        break;
      case 'category':
        color = Colors.purple;
        label = 'CATEGORY';
        break;
      case 'product':
        color = Colors.orange;
        label = 'PRODUCT';
        break;
      default:
        color = Colors.grey;
        label = 'GENERAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateCouponDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateCoupon(),
    );
  }

  void _editCoupon(BuildContext context, String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => CreateCoupon(existingId: id, existingData: data),
    );
  }

  Future<void> _toggleCoupon(BuildContext context, String id, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('coupons').doc(id).update({
        'is_active': !currentStatus,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? 'Coupon deactivated' : 'Coupon activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCoupon(BuildContext context, String id, String code) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: Text('Are you sure you want to delete coupon "$code"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('coupons').doc(id).delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Coupon deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
