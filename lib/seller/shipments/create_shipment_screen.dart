import 'package:flutter/material.dart';
import '../../models/seller_model.dart';
import '../../models/warehouse_model.dart';
import '../../models/shipment_model.dart';
import '../../services/seller_service.dart';

class CreateShipmentScreen extends StatefulWidget {
  final SellerModel seller;

  const CreateShipmentScreen({super.key, required this.seller});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  final SellerService _sellerService = SellerService();
  int _currentStep = 0;
  
  String? _selectedWarehouseId;
  WarehouseModel? _selectedWarehouse; // Keep for name/address reference
  final List<ShipmentItem> _selectedItems = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Shipment'),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _cancelStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                if (_currentStep < 2)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue'),
                  ),
                if (_currentStep == 2)
                  ElevatedButton(
                    onPressed: _submitShipment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Shipment'),
                  ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Warehouse'),
            content: _buildWarehouseStep(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: const Text('Products'),
            content: _buildProductStep(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: const Text('Review'),
            content: _buildReviewStep(),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a warehouse')),
      );
      return;
    }
    if (_currentStep == 1 && _selectedItems.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product')),
      );
       return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _cancelStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ...

  // --- Step 1: Warehouse Selection ---
  Widget _buildWarehouseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select destination warehouse:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<List<WarehouseModel>>(
          stream: _sellerService.getNearbyWarehouses(widget.seller.city),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) return const Text('No warehouses found in your area.');

            return Column(
              children: snapshot.data!.map((warehouse) {
                return RadioListTile<String>(
                  title: Text(warehouse.name),
                  subtitle: Text(warehouse.address),
                  value: warehouse.id,
                  groupValue: _selectedWarehouseId,
                  activeColor: const Color(0xFF0D9759),
                  onChanged: (val) {
                    setState(() {
                      _selectedWarehouseId = val;
                      _selectedWarehouse = warehouse;
                    });
                  },
                  secondary: const Icon(Icons.warehouse),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // --- Step 2: Product Selection ---
  Widget _buildProductStep() {
    return SizedBox(
      height: 400, // Fixed height for scrolling
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _sellerService.getSellerInventory(widget.seller.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Text('No ACTIVE products found.'),
                   const SizedBox(height: 8),
                   Text('Seller ID: ${widget.seller.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                   const Text('Make sure your products are "Active" in the catalog.', 
                     textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
                ],
              ),
            );
          }
          
          final inventory = snapshot.data!;
          return ListView.builder(
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final prod = inventory[index];
              final productId = prod['id'];
              final productName = prod['name'] ?? 'Unknown';
              final unit = prod['unit'] ?? 'unit';
              
              // Check if selected
              final existingIndex = _selectedItems.indexWhere((i) => i.productId == productId);
              final isSelected = existingIndex != -1;
              final currentQty = isSelected ? _selectedItems[existingIndex].quantity : 0;

              return Card(
                elevation: 0,
                color: isSelected ? Colors.green.withOpacity(0.05) : null,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isSelected ? Colors.green : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  activeColor: const Color(0xFF0D9759),
                  title: Text(productName),
                  subtitle: isSelected 
                    ? Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (currentQty > 1) {
                                setState(() {
                                   _updateQty(productId, productName, unit, currentQty - 1);
                                });
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('$currentQty $unit'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                               setState(() {
                                   _updateQty(productId, productName, unit, currentQty + 1);
                                });
                            },
                             padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : const Text('Tap to add'), 
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                         _updateQty(productId, productName, unit, 10); // Default start 10
                      } else {
                         _selectedItems.removeWhere((i) => i.productId == productId);
                      }
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _updateQty(String id, String name, String unit, int qty) {
     final idx = _selectedItems.indexWhere((i) => i.productId == id);
     if (idx != -1) {
       _selectedItems[idx] = ShipmentItem(
         productId: id, 
         productName: name, 
         productUnit: unit, 
         quantity: qty
       );
     } else {
       _selectedItems.add(ShipmentItem(
         productId: id, 
         productName: name, 
         productUnit: unit, 
         quantity: qty
       ));
     }
  }

  // --- Step 3: Review ---
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destination: ${_selectedWarehouse?.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
         Text('${_selectedWarehouse?.address}, ${_selectedWarehouse?.city}'),
         const Divider(height: 30),
         const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
         const SizedBox(height: 10),
         ..._selectedItems.map((item) => Padding(
           padding: const EdgeInsets.symmetric(vertical: 4),
           child: Row(
             children: [
               Text(item.productName),
               const Spacer(),
               Text('${item.quantity} ${item.productUnit}', style: const TextStyle(fontWeight: FontWeight.bold)),
             ],
           ),
         )),
      ],
    );
  }

  Future<void> _submitShipment() async {
    if (_selectedWarehouse == null) return;
    setState(() => _isLoading = true);
    
    // Create Model
    final shipment = ShipmentModel(
      id: '', // Generated by Firestore
      sellerId: widget.seller.id,
      warehouseId: _selectedWarehouse!.id,
      warehouseName: _selectedWarehouse!.name,
      status: 'pending',
      items: _selectedItems,
      createdAt: DateTime.now(),
    );

    // Call Service
    final result = await _sellerService.createShipment(shipment);

    setState(() => _isLoading = false);

    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment created successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create shipment')),
        );
      }
    }
  }
}
