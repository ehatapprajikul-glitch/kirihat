import 'package:flutter/material.dart';

class OrderFilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const OrderFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip('All', 'all', Icons.list),
          _buildChip('Today', 'today', Icons.today),
          _buildChip('Standard', 'standard', Icons.local_shipping),
          _buildChip('Instant', 'instant', Icons.flash_on),
          _buildChip('COD', 'cod', Icons.money),
          _buildChip('Online', 'online', Icons.credit_card),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, IconData icon) {
    final isSelected = selectedFilter == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onFilterChanged(value),
        backgroundColor: Colors.white,
        selectedColor: Colors.deepOrange.withOpacity(0.2),
        checkmarkColor: Colors.deepOrange,
        side: BorderSide(
          color: isSelected ? Colors.deepOrange : Colors.grey[300]!,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.deepOrange : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
