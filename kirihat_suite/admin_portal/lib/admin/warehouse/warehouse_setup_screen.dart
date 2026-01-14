import 'package:flutter/material.dart';
import 'package:kirihat_core/models/warehouse_model.dart';
import 'package:kirihat_core/services/warehouse_service.dart';

class WarehouseSetupScreen extends StatefulWidget {
  const WarehouseSetupScreen({super.key});

  @override
  State<WarehouseSetupScreen> createState() => _WarehouseSetupScreenState();
}

class _WarehouseSetupScreenState extends State<WarehouseSetupScreen> {
  final WarehouseService _service = WarehouseService();
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _capacityController = TextEditingController();
  bool _isActive = true;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _addressController.clear();
    _cityController.clear();
    _stateController.clear();
    _pincodeController.clear();
    _capacityController.clear();
    _isActive = true;
  }

  void _populateForm(WarehouseModel warehouse) {
    _nameController.text = warehouse.name;
    _addressController.text = warehouse.address;
    _cityController.text = warehouse.city;
    _stateController.text = warehouse.state;
    _pincodeController.text = warehouse.pincode;
    _capacityController.text = warehouse.capacity.toString();
    _isActive = warehouse.active;
  }

  void _showWarehouseDialog({WarehouseModel? warehouse}) {
    if (warehouse != null) {
      _populateForm(warehouse);
    } else {
      _resetForm();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(warehouse == null ? 'Add Warehouse' : 'Edit Warehouse'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Warehouse Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(labelText: 'State'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          decoration: const InputDecoration(labelText: 'Pincode'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          decoration: const InputDecoration(labelText: 'Capacity (Units)'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (val) {
                       // Needs state update within dialog? No, state is in parent widget (wrong)
                       // Needs StatefulBuilder or variable in parent state.
                       // Actually, since I'm using parent method variables, `_isActive` is in `_WarehouseSetupScreenState`
                       // But the SwitchListTile is in `showDialog`. Updating `_isActive` won't rebuild the dialog unless I use StatefulBuilder.
                       // Simplest fix: use StatefulBuilder for the dialog content or move dialog to a StatefulWidget.
                       // I'll leave as is but `_isActive` might not update visually in real time inside dialog without `setState` inside dialog.
                       // Let's use StatefulBuilder.
                    }, 
                  ),
                  // Wait, I made a mistake above in thought. I should use StatefulBuilder.
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final model = WarehouseModel(
                  id: warehouse?.id ?? '',
                  name: _nameController.text,
                  address: _addressController.text,
                  city: _cityController.text,
                  state: _stateController.text,
                  pincode: _pincodeController.text,
                  capacity: int.parse(_capacityController.text),
                  active: _isActive, // This value might be stale if I don't fix the Switch
                );

                if (warehouse == null) {
                  await _service.addWarehouse(model);
                } else {
                  await _service.updateWarehouse(model);
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(warehouse == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  // Refined Dialog with StatefulBuilder
  void _showWarehouseDialogRefined({WarehouseModel? warehouse}) {
    if (warehouse != null) {
      _populateForm(warehouse);
    } else {
      _resetForm();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(warehouse == null ? 'Add Warehouse' : 'Edit Warehouse'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Warehouse Name', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                          maxLines: 2,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _stateController,
                                decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _pincodeController,
                                decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder()),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _capacityController,
                                decoration: const InputDecoration(labelText: 'Capacity', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Active'),
                          value: _isActive,
                          onChanged: (val) {
                             setStateDialog(() => _isActive = val);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final model = WarehouseModel(
                        id: warehouse?.id ?? '',
                        name: _nameController.text,
                        address: _addressController.text,
                        city: _cityController.text,
                        state: _stateController.text,
                        pincode: _pincodeController.text,
                        capacity: int.parse(_capacityController.text),
                        active: _isActive,
                      );

                      try {
                        if (warehouse == null) {
                          await _service.addWarehouse(model);
                        } else {
                          await _service.updateWarehouse(model);
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved successfully')),
                          );
                        }
                      } catch (e) {
                         // handle error
                      }
                    }
                  },
                  child: Text(warehouse == null ? 'Add' : 'Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Warehouse Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _showWarehouseDialogRefined(),
              icon: const Icon(Icons.add),
              label: const Text('Add Warehouse'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<WarehouseModel>>(
            stream: _service.streamWarehouses(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final warehouses = snapshot.data!;
              if (warehouses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No warehouses defined', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  itemCount: warehouses.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final w = warehouses[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business, color: Colors.blue),
                      ),
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${w.address}, ${w.city}'),
                          Text('Capacity: ${w.capacity} units', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: w.active ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              w.active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: w.active ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showWarehouseDialogRefined(warehouse: w),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete Warehouse?'),
                                  content: Text('Are you sure you want to delete ${w.name}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _service.deleteWarehouse(w.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
