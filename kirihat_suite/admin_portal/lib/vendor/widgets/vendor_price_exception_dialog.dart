import 'package:flutter/material.dart';
import 'package:kirihat_core/services/price_sync_service.dart';

/// Dialog for vendors to request price exception/override
class VendorPriceExceptionDialog extends StatefulWidget {
  final String vendorId;
  final String productId;
  final String productName;
  final double currentPrice;

  const VendorPriceExceptionDialog({
    super.key,
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.currentPrice,
  });

  @override
  State<VendorPriceExceptionDialog> createState() => _VendorPriceExceptionDialogState();
}

class _VendorPriceExceptionDialogState extends State<VendorPriceExceptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _proposedPriceController = TextEditingController();
  final _justificationController = TextEditingController();
  String _selectedReason = 'Market Competition';
  bool _isLoading = false;

  final List<String> _reasons = [
    'Market Competition',
    'Bulk Purchase Discount',
    'Clearance Sale',
    'Promotional Offer',
    'Expired/Near Expiry',
    'Damaged Packaging',
    'Other',
  ];

  @override
  void dispose() {
    _proposedPriceController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double? proposedPrice = double.tryParse(_proposedPriceController.text);
    double? percentDiff;
    if (proposedPrice != null && widget.currentPrice > 0) {
      percentDiff = ((proposedPrice - widget.currentPrice) / widget.currentPrice) * 100;
    }

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.request_quote, color: Color(0xFF34A853), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Request Price Exception',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Product Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Current Synced Price: '),
                        Text(
                          '₹${widget.currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF34A853),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Reason Selection
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason for Exception *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: _reasons.map((reason) {
                  return DropdownMenuItem(value: reason, child: Text(reason));
                }).toList(),
                onChanged: (val) => setState(() => _selectedReason = val!),
              ),

              const SizedBox(height: 16),

              // Proposed Price
              TextFormField(
                controller: _proposedPriceController,
                decoration: InputDecoration(
                  labelText: 'Proposed Price (₹) *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  suffixText: percentDiff != null
                      ? '${percentDiff > 0 ? '+' : ''}${percentDiff.toStringAsFixed(1)}%'
                      : null,
                  suffixStyle: TextStyle(
                    color: percentDiff != null
                        ? (percentDiff > 0 ? Colors.red : Colors.green)
                        : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  double? price = double.tryParse(val);
                  if (price == null) return 'Invalid price';
                  if (price <= 0) return 'Must be positive';
                  if (price == widget.currentPrice) return 'Same as current price';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Justification
              TextFormField(
                controller: _justificationController,
                decoration: const InputDecoration(
                  labelText: 'Justification *',
                  hintText: 'Explain why this price change is necessary',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (val.length < 20) return 'At least 20 characters required';
                  return null;
                },
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This request will be reviewed by the admin. Approval is not guaranteed.',
                        style: TextStyle(color: Colors.orange[900], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit Request'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final priceSync = PriceSyncService();
      String? requestId = await priceSync.createPriceOverrideRequest(
        vendorId: widget.vendorId,
        productId: widget.productId,
        currentPrice: widget.currentPrice,
        proposedPrice: double.parse(_proposedPriceController.text),
        reason: _selectedReason,
        justification: _justificationController.text.trim(),
      );

      if (requestId != null && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price exception request submitted successfully!'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
      } else {
        throw Exception('Failed to create request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
