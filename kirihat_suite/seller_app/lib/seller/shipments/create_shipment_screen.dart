import 'package:flutter/material.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/models/warehouse_model.dart';
import 'package:kirihat_core/models/shipment_model.dart';
import 'package:kirihat_core/services/seller_service.dart';

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

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  final TextEditingController _productSearchCtrl = TextEditingController();
  String _productSearchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

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
          switch (_currentStep) {
            case 0:
              return const SizedBox.shrink(); // Hide default buttons for step 0 (custom Select buttons)
            case 1:
            case 2:
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
            default:
              return const SizedBox.shrink();
          }
        },
        steps: [
          Step(
            title: const Text('Select Hub'),
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

  // ...

  // --- Step 1: Warehouse Selection ---
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

  // --- Step 1: Warehouse Selection ---
  Widget _buildWarehouseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Destination Hub', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        const SizedBox(height: 8),
        Text(
          'Search for a warehouse to send your stock to.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),
        
        // Search Bar
        TextField(
          controller: _searchCtrl,
          onChanged: (val) {
            setState(() => _searchQuery = val.toLowerCase().trim());
          },
          decoration: InputDecoration(
            hintText: 'Search by Name, City, or Pincode...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          ),
        ),
        const SizedBox(height: 16),

        StreamBuilder<List<WarehouseModel>>(
          stream: _sellerService.getAllWarehouses(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState('No warehouses available.');
            }

            final warehouses = snapshot.data!;
            
            // Client-side Filtering
            final filteredWarehouses = warehouses.where((w) {
              if (_searchQuery.isEmpty) return true;
              return w.name.toLowerCase().contains(_searchQuery) ||
                     w.city.toLowerCase().contains(_searchQuery) ||
                     w.pincode.contains(_searchQuery) ||
                     w.address.toLowerCase().contains(_searchQuery);
            }).toList();

            if (filteredWarehouses.isEmpty) {
              return _buildEmptyState('No results for "$_searchQuery"');
            }

            return Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                itemCount: filteredWarehouses.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final warehouse = filteredWarehouses[index];
                  final isSelected = _selectedWarehouseId == warehouse.id;
                  final isRecommended = warehouse.city.toLowerCase() == widget.seller.city.toLowerCase();

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0D9759) : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                           setState(() {
                             _selectedWarehouseId = warehouse.id;
                             _selectedWarehouse = warehouse;
                           });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.warehouse_outlined, color: Colors.indigo.shade700, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                warehouse.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            if (isRecommended)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Recommended',
                                                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${warehouse.address}, ${warehouse.city} - ${warehouse.pincode}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected) ...[
                                const Divider(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _nextStep,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9759),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Proceed with this Warehouse'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(msg, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Product Selection ---
  Widget _buildProductStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Products', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        const SizedBox(height: 8),
        Text(
          'Choose products to add to this shipment.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Product Search Bar
        TextField(
          controller: _productSearchCtrl,
          onChanged: (val) {
            setState(() => _productSearchQuery = val.toLowerCase().trim());
          },
          decoration: InputDecoration(
            hintText: 'Search by Title, Keywords...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
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

              // Client-side Product Filtering
              final filteredInventory = inventory.where((prod) {
                if (_productSearchQuery.isEmpty) return true;
                
                final name = (prod['name'] as String? ?? '').toLowerCase();
                final keywords = (prod['keywords'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
                
                // Match Name
                if (name.contains(_productSearchQuery)) return true;
                
                // Match Keywords
                for (final k in keywords) {
                  if (k.contains(_productSearchQuery)) return true;
                }
                
                return false;
              }).toList();

              if (filteredInventory.isEmpty) {
                 return _buildEmptyState('No products found for "$_productSearchQuery"');
              }

              return ListView.builder(
                itemCount: filteredInventory.length,
                itemBuilder: (context, index) {
                  final prod = filteredInventory[index];
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
        ),
      ],
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
