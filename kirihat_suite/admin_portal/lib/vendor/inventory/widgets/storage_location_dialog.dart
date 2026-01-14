import 'package:flutter/material.dart';

class StorageLocationDialog extends StatefulWidget {
  final Map<String, dynamic>? currentLocation;
  final String productName;

  const StorageLocationDialog({
    super.key,
    this.currentLocation,
    required this.productName,
  });

  @override
  State<StorageLocationDialog> createState() => _StorageLocationDialogState();
}

class _StorageLocationDialogState extends State<StorageLocationDialog> {
  late TextEditingController _aisleController;
  late TextEditingController _shelfController;
  late TextEditingController _binController;

  @override
  void initState() {
    super.initState();
    _aisleController = TextEditingController(
      text: widget.currentLocation?['aisle'] ?? '',
    );
    _shelfController = TextEditingController(
      text: widget.currentLocation?['shelf'] ?? '',
    );
    _binController = TextEditingController(
      text: widget.currentLocation?['bin'] ?? '',
    );
  }

  @override
  void dispose() {
    _aisleController.dispose();
    _shelfController.dispose();
    _binController.dispose();
    super.dispose();
  }

  bool _hasLocation() {
    return _aisleController.text.isNotEmpty ||
        _shelfController.text.isNotEmpty ||
        _binController.text.isNotEmpty;
  }

  Map<String, String>? _getLocation() {
    if (!_hasLocation()) return null;
    return {
      'aisle': _aisleController.text.trim(),
      'shelf': _shelfController.text.trim(),
      'bin': _binController.text.trim(),
    };
  }

  void _clearLocation() {
    setState(() {
      _aisleController.clear();
      _shelfController.clear();
      _binController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on, color: Colors.deepOrange),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Storage Location', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set location for:', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(widget.productName, 
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aisleController,
                    decoration: const InputDecoration(
                      labelText: 'Aisle',
                      hintText: 'e.g., A3',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.view_week),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _shelfController,
                    decoration: const InputDecoration(
                      labelText: 'Shelf',
                      hintText: 'e.g., S12',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.horizontal_split),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _binController,
                    decoration: const InputDecoration(
                      labelText: 'Bin',
                      hintText: 'e.g., B5',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (_hasLocation())
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: ${_aisleController.text.isEmpty ? '-' : _aisleController.text} / '
                        '${_shelfController.text.isEmpty ? '-' : _shelfController.text} / '
                        '${_binController.text.isEmpty ? '-' : _binController.text}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_hasLocation())
          TextButton.icon(
            onPressed: _clearLocation,
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, _getLocation()),
          icon: const Icon(Icons.save),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
