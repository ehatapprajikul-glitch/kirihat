import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorCatalogSelectionScreen extends StatefulWidget {
  const VendorCatalogSelectionScreen({super.key});

  @override
  State<VendorCatalogSelectionScreen> createState() => _VendorCatalogSelectionScreenState();
}

class _VendorCatalogSelectionScreenState extends State<VendorCatalogSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String vendorId = FirebaseAuth.instance.currentUser!.uid;
  
  List<String> _selectedHeroIds = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    try {
      final doc = await _firestore
          .collection('vendor_catalog_selections')
          .doc(vendorId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _selectedHeroIds = List<String>.from(data['hero_category_ids'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading selections: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSelections() async {
    setState(() => _isSaving = true);

    try {
      await _firestore.collection('vendor_catalog_selections').doc(vendorId).set({
        'vendor_id': vendorId,
        'hero_category_ids': _selectedHeroIds,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catalog selection saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Catalog Selection'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select which product categories you want to show to your customers. Only categories where you have inventory will be visible.',
                          style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),

                // Hero Categories List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('hero_categories')
                        .orderBy('position')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final heroCategories = snapshot.data!.docs;

                      if (heroCategories.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'No hero categories available yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Contact admin to create hero categories',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: heroCategories.length,
                        itemBuilder: (context, index) {
                          final doc = heroCategories[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          return _buildHeroCategoryCard(doc.id, data);
                        },
                      );
                    },
                  ),
                ),

                // Save Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedHeroIds.length} categories selected',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSelections,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Selection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCategoryCard(String heroId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed';
    final iconUrl = data['icon_url'];
    final categoryIds = List<String>.from(data['category_ids'] ?? []);
    final isSelected = _selectedHeroIds.contains(heroId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0D9759) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedHeroIds.remove(heroId);
            } else {
              _selectedHeroIds.add(heroId);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0D9759) : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected ? const Color(0xFF0D9759) : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),

              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: iconUrl != null
                      ? DecorationImage(
                          image: NetworkImage(iconUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: iconUrl == null
                    ? const Icon(Icons.category, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${categoryIds.length} sub-categories',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Selected Badge
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9759),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
