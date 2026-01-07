import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:kirihat_core/services/cloudinary_service.dart';
import 'package:kirihat_core/services/banner_service.dart';
import 'package:kirihat_core/models/banner_model.dart';

class HeroBannerManagementScreen extends StatefulWidget {
  const HeroBannerManagementScreen({super.key});

  @override
  State<HeroBannerManagementScreen> createState() => _HeroBannerManagementScreenState();
}

class _HeroBannerManagementScreenState extends State<HeroBannerManagementScreen> {
  final BannerService _bannerService = BannerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero Banner Management'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<BannerModel>>(
        stream: _bannerService.getAllBanners(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final banners = snapshot.data!;
          final activeCount = banners.where((b) => b.isActive).length;

          if (banners.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No banners yet', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Banner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header with count
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Active Banners: $activeCount/12 • Drag to reorder',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (activeCount >= 12)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIMIT REACHED',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: banners.length,
                  onReorder: (oldIndex, newIndex) => _reorderBanners(banners, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return _buildBannerCard(banner, key: ValueKey(banner.id));
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<BannerModel>>(
        stream: _bannerService.getAllBanners(),
        builder: (context, snapshot) {
          final activeCount = snapshot.data?.where((b) => b.isActive).length ?? 0;
          final canAddMore = activeCount < 12;

          return FloatingActionButton.extended(
            onPressed: canAddMore
                ? () => _showAddEditDialog()
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Maximum 12 active banners reached'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
            backgroundColor: canAddMore ? const Color(0xFF0D9759) : Colors.grey,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Banner'),
          );
        },
      ),
    );
  }

  Widget _buildBannerCard(BannerModel banner, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 12),
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(banner.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          _getHyperlinkDisplayText(banner),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            _buildHyperlinkTypeBadge(banner.hyperlinkType),
            const SizedBox(width: 8),
            if (!banner.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                banner.isActive ? Icons.visibility : Icons.visibility_off,
                color: banner.isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleBannerStatus(banner),
              tooltip: banner.isActive ? 'Active (click to deactivate)' : 'Inactive (click to activate)',
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showAddEditDialog(banner: banner),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteBanner(banner),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHyperlinkTypeBadge(String type) {
    Color color;
    String label;

    switch (type) {
      case 'category':
        color = Colors.green;
        label = 'CATEGORY';
        break;
      case 'product':
        color = Colors.blue;
        label = 'PRODUCT';
        break;
      case 'external':
        color = Colors.purple;
        label = 'EXTERNAL';
        break;
      default:
        color = Colors.grey;
        label = 'NO LINK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getHyperlinkDisplayText(BannerModel banner) {
    switch (banner.hyperlinkType) {
      case 'category':
        return 'Category: ${banner.hyperlinkValue}';
      case 'product':
        return 'Product ID: ${banner.hyperlinkValue}';
      case 'external':
        return 'URL: ${banner.hyperlinkValue}';
      default:
        return 'No hyperlink';
    }
  }

  Future<void> _reorderBanners(List<BannerModel> banners, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = banners.removeAt(oldIndex);
    banners.insert(newIndex, item);

    await _bannerService.reorderBanners(banners);
  }

  Future<void> _toggleBannerStatus(BannerModel banner) async {
    try {
      await _bannerService.toggleBannerStatus(banner.id, !banner.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(banner.isActive ? 'Banner deactivated' : 'Banner activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBanner(BannerModel banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Banner?'),
        content: const Text('Are you sure you want to delete this banner? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bannerService.deleteBanner(banner.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banner deleted'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAddEditDialog({BannerModel? banner}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          child: _BannerFormDialog(banner: banner),
        ),
      ),
    );
  }
}

// Separate widget for the form dialog
class _BannerFormDialog extends StatefulWidget {
  final BannerModel? banner;

  const _BannerFormDialog({this.banner});

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  final BannerService _bannerService = BannerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _hyperlinkType = 'none';
  String _hyperlinkValue = '';
  String? _existingImageUrl;
  Uint8List? _selectedImageBytes;
  bool _isActive = true;
  bool _isLoading = false;

  // For category/product selection
  String? _selectedCategory;
  String? _selectedProduct;

  @override
  void initState() {
    super.initState();
    if (widget.banner != null) {
      _hyperlinkType = widget.banner!.hyperlinkType;
      _hyperlinkValue = widget.banner!.hyperlinkValue;
      _existingImageUrl = widget.banner!.imageUrl;
      _isActive = widget.banner!.isActive;

      if (_hyperlinkType == 'category') {
        _selectedCategory = _hyperlinkValue;
      } else if (_hyperlinkType == 'product') {
        _selectedProduct = _hyperlinkValue;
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (_existingImageUrl == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    if (_hyperlinkType != 'none' && _hyperlinkValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete hyperlink configuration')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = _existingImageUrl ?? '';

      // Upload new image if selected
      if (_selectedImageBytes != null) {
        imageUrl = await CloudinaryService.uploadImage(
          _selectedImageBytes!,
          folder: 'hero_banners',
        ) ??
            '';
      }

      final banner = BannerModel(
        id: widget.banner?.id ?? '',
        imageUrl: imageUrl,
        hyperlinkType: _hyperlinkType,
        hyperlinkValue: _hyperlinkValue,
        position: widget.banner?.position ?? 0,
        isActive: _isActive,
      );

      if (widget.banner == null) {
        await _bannerService.addBanner(banner);
      } else {
        await _bannerService.updateBanner(widget.banner!.id, banner);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.banner == null ? 'Banner created!' : 'Banner updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0D9759),
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.image, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.banner == null ? 'Add Banner' : 'Edit Banner',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Upload
                const Text('Banner Image *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                      image: _selectedImageBytes != null
                          ? DecorationImage(image: MemoryImage(_selectedImageBytes!), fit: BoxFit.cover)
                          : (_existingImageUrl != null
                              ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: _selectedImageBytes == null && _existingImageUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Click to upload banner image', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Banner Image Guidelines
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Banner Guidelines',
                            style: TextStyle(
                              color: Colors.blue, 
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('• Format: JPG or PNG', style: TextStyle(fontSize: 11)),
                      Text('• Aspect Ratio: 2:3 (Portrait)', style: TextStyle(fontSize: 11)),
                      Text('• Suggested Resolution: 800x1200px', style: TextStyle(fontSize: 11)),
                      Text('• Max size: 2MB', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Hyperlink Type
                const Text('Hyperlink Type *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _hyperlinkType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No Link')),
                    DropdownMenuItem(value: 'category', child: Text('Category')),
                    DropdownMenuItem(value: 'product', child: Text('Product')),
                    DropdownMenuItem(value: 'external', child: Text('External URL')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _hyperlinkType = value!;
                      _hyperlinkValue = '';
                      _selectedCategory = null;
                      _selectedProduct = null;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Conditional hyperlink value input
                if (_hyperlinkType == 'category') _buildCategorySelector(),
                if (_hyperlinkType == 'product') _buildProductSelector(),
                if (_hyperlinkType == 'external') _buildExternalUrlInput(),

                const SizedBox(height: 24),

                // Active toggle
                SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Active'),
                  subtitle: const Text('Inactive banners won\'t appear on customer home'),
                  activeColor: const Color(0xFF0D9759),
                ),
              ],
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9759),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(widget.banner == null ? 'Create' : 'Update'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Category *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('categories').orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }

            final categories = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: categories.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: data['name'],
                  child: Text(data['name'] ?? 'Unnamed'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                  _hyperlinkValue = value ?? '';
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Product *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('master_products').limit(100).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }

            final products = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              value: _selectedProduct,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search and select product',
              ),
              items: products.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(data['name'] ?? 'Unnamed Product'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProduct = value;
                  _hyperlinkValue = value ?? '';
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildExternalUrlInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('External URL *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'https://example.com',
          ),
          onChanged: (value) {
            _hyperlinkValue = value;
          },
          controller: TextEditingController(text: _hyperlinkValue),
        ),
      ],
    );
  }
}
