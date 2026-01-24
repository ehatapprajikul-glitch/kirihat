import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import 'package:kirihat_core/utils/currency_helper.dart';
import '../../../widgets/order_timer.dart'; // Import from lib/widgets/

class OrderCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onAssignRider;
  final VoidCallback? onGenerateLabel;
  final VoidCallback? onCancelOrder;
  final VoidCallback? onViewDetails;
  final VoidCallback? onAcceptOrder;
  final VoidCallback? onMarkAsPacked;

  final bool isSelectionMode;
  final bool isSelected;
  final Function(bool?)? onSelected;

  const OrderCard({
    super.key,
    required this.order,
    this.onAssignRider,
    this.onGenerateLabel,
    this.onCancelOrder,
    this.onViewDetails,
    this.onAcceptOrder,
    this.onMarkAsPacked,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isSelected ? Colors.deepOrange : Colors.grey[200]!,
          width: widget.isSelected ? 2 : 1,
        ),
      ),
      color: widget.isSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.white,
      child: InkWell(
        onTap: widget.isSelectionMode 
            ? () => widget.onSelected?.call(!widget.isSelected)
            : _toggleExpanded,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              
              // Animated expand/collapse section
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Column(
                  children: [
                    if (_isExpanded) ...[
                      const Divider(height: 24),
                      _buildCustomerInfo(),
                      const SizedBox(height: 12),
                      _buildItems(),
                    ],
                  ],
                ),
              ),
              
              const Divider(height: 24),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        if (widget.isSelectionMode) ...[
          Checkbox(
            value: widget.isSelected,
            onChanged: widget.onSelected,
            activeColor: Colors.deepOrange,
          ),
          const SizedBox(width: 8),
        ],
        
        // Order ID with icon
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag, color: Colors.deepOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${widget.order.orderId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!_isExpanded)
                          Text(
                            CurrencyHelper.format(widget.order.totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    OrderTimer(
                      createdAt: widget.order.createdAt,
                      deliveryMode: widget.order.deliveryMode,
                      status: widget.order.status,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 8),

        // Status Badge (hidden in collapsed to save space if needed, but keeping for now)
        _buildStatusBadge(),
        
        const SizedBox(width: 8),
        
        // Expansion Icon
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[400],
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (widget.order.status) {
      case 'Pending':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.schedule;
        break;
      case 'Processing':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        icon = Icons.sync;
        break;
      case 'Shipped':
        bgColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        icon = Icons.local_shipping;
        break;
      case 'Delivered':
      case 'Completed':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'Cancelled':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        break;
      default:
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            widget.order.status,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(widget.order.customerPhone, style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.order.deliveryAddress.fullAddress,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          
          // Rider info if shipped
          if (widget.order.riderName != null) ...[
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.two_wheeler, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rider: ${widget.order.riderName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          widget.order.riderPhone ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  if (widget.order.deliveryPin != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        'PIN: ${widget.order.deliveryPin}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Items',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.order.itemCount}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[200],
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20),
                        )
                      : const Icon(Icons.image, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.quantity}x ${CurrencyHelper.format(item.price)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyHelper.format(item.total),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Payment Method Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.order.isCOD ? Colors.amber.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.order.isCOD ? Colors.amber.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.order.isCOD ? Icons.money : Icons.payment,
                    size: 14,
                    color: widget.order.isCOD ? Colors.amber.shade700 : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.order.paymentMethod,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.order.isCOD ? Colors.amber.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Total Amount
            Text(
              CurrencyHelper.format(widget.order.totalAmount),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Action Buttons
        if (widget.order.isPending)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancelOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onAcceptOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept Order'),
                ),
              ),
            ],
          ),
          
        if (widget.order.isProcessing)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onGenerateLabel,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print Label'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onMarkAsPacked,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.inventory_2, size: 18),
                  label: const Text('Pack Order'),
                ),
              ),
            ],
          ),

        if (widget.order.isPacked)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onGenerateLabel,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print Label'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onAssignRider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delivery_dining, size: 18),
                  label: const Text('Assign Rider'),
                ),
              ),
            ],
          ),
          
        if (widget.order.isShipped)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onGenerateLabel,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print Label'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onViewDetails,
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        
        if (widget.order.status == 'Cancelled')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "Cancelled by ${(widget.order.cancelledBy ?? 'Unknown').toUpperCase()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    "Reason: ${widget.order.cancellationReason ?? 'Not specified'}",
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
                if (widget.order.cancelledAt != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Text(
                      DateFormat('MMM dd, hh:mm a').format(widget.order.cancelledAt!),
                      style: TextStyle(color: Colors.red.shade600, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
