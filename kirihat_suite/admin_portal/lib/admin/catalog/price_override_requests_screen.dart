import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/services/price_sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin screen to review and approve/reject vendor price override requests
class PriceOverrideRequestsScreen extends StatefulWidget {
  const PriceOverrideRequestsScreen({super.key});

  @override
  State<PriceOverrideRequestsScreen> createState() => _PriceOverrideRequestsScreenState();
}

class _PriceOverrideRequestsScreenState extends State<PriceOverrideRequestsScreen> {
  // Key to force refresh of StreamBuilders
  int _refreshKey = 0;

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Price Override Requests'),
          backgroundColor: const Color(0xFF34A853),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
                tooltip: "Refresh Requests",
            )
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Pending Requests'),
              Tab(text: 'Request History'),
            ],
          ),
        ),
        body: TabBarView(
          key: ValueKey(_refreshKey), // Rebuilds on refresh
          children: [
            _PendingRequestsTab(),
            _HistoryRequestsTab(),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final priceSyncService = PriceSyncService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: priceSyncService.getPendingPriceOverrideRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
             return _buildErrorView(context, snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'All price override requests have been reviewed',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var request = snapshot.data![index];
            return _PriceOverrideRequestCard(request: request, isHistory: false);
          },
        );
      },
    );
  }
}

class _HistoryRequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final priceSyncService = PriceSyncService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: priceSyncService.getHistoryPriceOverrideRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
             return _buildErrorView(context, snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No history available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var request = snapshot.data![index];
            return _PriceOverrideRequestCard(request: request, isHistory: true);
          },
        );
      },
    );
  }
}

Widget _buildErrorView(BuildContext context, Object? error) {
    String errorText = error.toString();
    String? url;
    
    // Attempt to extract URL from error message
    // Firestore failed-precondition usually contains "https://console.firebase.google.com/..."
    if (errorText.contains("https://")) {
        int startIndex = errorText.indexOf("https://");
        int endIndex = errorText.indexOf(" ", startIndex);
        if (endIndex == -1) endIndex = errorText.length;
        url = errorText.substring(startIndex, endIndex);
    }
    
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text("Error Loading Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    SelectableText(errorText, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                    if (url != null) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                            onPressed: () async {
                                final Uri uri = Uri.parse(url!);
                                if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch URL")));
                                }
                            },
                            icon: const Icon(Icons.link),
                            label: const Text("Create Missing Index"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                            ),
                        ),
                        const SizedBox(height: 8),
                         const Text("Click above to create the required database index, then Refresh.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ]
                ],
            )
        )
    );
}

class _PriceOverrideRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final bool isHistory;

  const _PriceOverrideRequestCard({required this.request, required this.isHistory});

  @override
  State<_PriceOverrideRequestCard> createState() => _PriceOverrideRequestCardState();
}

class _PriceOverrideRequestCardState extends State<_PriceOverrideRequestCard> {
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color get _statusColor {
      switch (widget.request['status']) {
          case 'approved': return Colors.green;
          case 'rejected': return Colors.red;
          default: return Colors.orange;
      }
  }

  @override
  Widget build(BuildContext context) {
    double currentPrice = widget.request['current_price']?.toDouble() ?? 0;
    double proposedPrice = widget.request['proposed_price']?.toDouble() ?? 0;
    
    // For approved requests that were edited, show original if available
    double? originalProposedPrice = widget.request['original_proposed_price']?.toDouble();
    
    double percentDiff = ((proposedPrice - currentPrice) / currentPrice) * 100;
    DateTime createdAt = (widget.request['created_at'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request['product_name'] ?? 'Product',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vendor: ${widget.request['vendor_name'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'Requested: ${_formatDate(createdAt)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (widget.request['status'] ?? 'PENDING').toString().toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Price Comparison
            Row(
              children: [
                Expanded(
                  child: _PriceBox(
                    label: 'Current Synced Price',
                    price: currentPrice,
                    color: const Color(0xFF34A853),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: percentDiff > 0 ? Colors.red : Colors.green,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percentDiff > 0 ? '+' : ''}${percentDiff.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: percentDiff > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PriceBox(
                    label: originalProposedPrice != null ? 'Approved Price' : 'Proposed Price',
                    price: proposedPrice,
                    color: percentDiff > 0 ? Colors.red : Colors.green,
                    subLabel: originalProposedPrice != null ? '(Orig: ₹$originalProposedPrice)' : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        widget.request['reason'] ?? 'No reason specified',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.request['justification'] ?? 'No justification provided',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (widget.isHistory && widget.request['admin_notes'] != null) ...[
                      const Divider(),
                      Text("Admin Notes: ${widget.request['admin_notes']}", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                  ]
                ],
              ),
            ),

            if (!widget.isHistory) ...[
                const SizedBox(height: 16),
                // Admin Notes
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Notes (Optional)',
                    hintText: 'Add comments for this decision',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                     Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _reject,
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                             onPressed: _isProcessing ? null : _showEditDialog,
                             icon: const Icon(Icons.edit),
                             label: const Text('Edit'),
                             style: OutlinedButton.styleFrom(
                                 foregroundColor: Colors.blue,
                                 padding: const EdgeInsets.symmetric(vertical: 12)
                             )
                        )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _approve(),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34A853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog() async {
      double proposed = widget.request['proposed_price']?.toDouble() ?? 0;
      final controller = TextEditingController(text: proposed.toString());
      
      await showDialog(
          context: context, 
          builder: (context) => AlertDialog(
              title: const Text("Edit Approved Price"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const Text("Approve this request with a revised price?"),
                      const SizedBox(height: 16),
                      TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Revised Price", border: OutlineInputBorder()),
                      )
                  ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () {
                          Navigator.pop(context);
                          double? newPrice = double.tryParse(controller.text);
                          if (newPrice != null) {
                              _approve(revisedPrice: newPrice);
                          }
                      }, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text("Approve Revised")
                  )
              ],
          )
      );
  }

  Future<void> _approve({double? revisedPrice}) async {
    setState(() => _isProcessing = true);

    try {
      final priceSyncService = PriceSyncService();
      String adminId = 'admin_user_id'; 
      
      await priceSyncService.approvePriceOverride(
        widget.request['id'],
        adminId,
        adminNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        revisedPrice: revisedPrice
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price override approved successfully!'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for rejection')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final priceSyncService = PriceSyncService();
      String adminId = 'admin_user_id';
      
      await priceSyncService.rejectPriceOverride(
        widget.request['id'],
        adminId,
        _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price override rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final double price;
  final Color color;
  final String? subLabel;

  const _PriceBox({
    required this.label,
    required this.price,
    required this.color,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '₹${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subLabel != null)
             Text(
                subLabel!,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
             )
        ],
      ),
    );
  }
}
