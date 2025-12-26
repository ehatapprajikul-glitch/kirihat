import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({super.key});
  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _searchQuery = "";

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descController = TextEditingController();

  String _heroImageUrl = "";
  List<String> _galleryUrls = [];
  bool _isUploadingImage = false;

  String _selectedCategory = 'Groceries';
  final List<String> _categories = [
    'Groceries',
    'Vegetables',
    'Snacks',
    'Household',
    'Electronics',
    'Fashion',
    'General',
  ];

  Future<void> _pickAndUploadImage({bool isHero = true}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      Uint8List imgData = await image.readAsBytes();
      var uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/du634o3sf/image/upload",
      );
      var request = http.MultipartRequest("POST", uri);
      request.fields['upload_preset'] = "ouofgw7n";
      request.files.add(
        http.MultipartFile.fromBytes('file', imgData, filename: "product.jpg"),
      );

      var response = await request.send();

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var jsonMap = jsonDecode(String.fromCharCodes(responseData));
        String downloadUrl = jsonMap['secure_url'];

        setState(() {
          if (isHero) {
            _heroImageUrl = downloadUrl;
          } else {
            _galleryUrls.add(downloadUrl);
          }
        });
        messenger.showSnackBar(const SnackBar(content: Text("✅ Uploaded!")));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text("Upload Failed")));
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) {
      setState(() => _isUploadingImage = false);
    }
  }

  void _showProductDialog({Map<String, dynamic>? oldData, String? docId}) {
    _heroImageUrl = "";
    _galleryUrls = [];
    _isUploadingImage = false;

    if (oldData != null) {
      _nameController.text = oldData['name'];
      _priceController.text = oldData['price'].toString();
      _mrpController.text = (oldData['mrp'] ?? oldData['price']).toString();
      _stockController.text = oldData['stock'].toString();
      _tagsController.text = (oldData['tags'] as List<dynamic>? ?? []).join(
        ', ',
      );
      _descController.text = oldData['description'] ?? '';
      _heroImageUrl = oldData['imageUrl'] ?? '';
      _selectedCategory = _categories.contains(oldData['category'])
          ? oldData['category']
          : 'Groceries';

      if (oldData['gallery'] != null) {
        for (var url in oldData['gallery']) {
          _galleryUrls.add(url.toString());
        }
      }
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(docId == null ? "Add New Product" : "Edit Product"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Product Images",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          await _pickAndUploadImage(isHero: true);
                          setDialogState(() {});
                        },
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.grey),
                          ),
                          child: _isUploadingImage
                              ? const Center(child: CircularProgressIndicator())
                              : (_heroImageUrl.isNotEmpty)
                                  ? Image.network(_heroImageUrl,
                                      fit: BoxFit.cover)
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt),
                                        Text("Tap to Upload"),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        ..._galleryUrls.map(
                          (url) => Chip(
                            label: const Text("Img"),
                            avatar: const Icon(Icons.image, size: 16),
                            onDeleted: () =>
                                setDialogState(() => _galleryUrls.remove(url)),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _pickAndUploadImage(isHero: false);
                            setDialogState(() {});
                          },
                          icon: const Icon(
                            Icons.add_a_photo,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const Divider(thickness: 2),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Product Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Selling ₹",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _mrpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "MRP ₹",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Stock",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField(
                            initialValue: _selectedCategory,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(
                                  () => _selectedCategory = v.toString(),
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Category",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: "Keywords/Tags",
                        hintText: "rice, basmati, food",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: _isUploadingImage
                    ? null
                    : () => _saveProduct(docId, ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveProduct(String? docId, BuildContext ctx) async {
    if (_nameController.text.isEmpty) {
      return;
    }

    List<String> keywords = _nameController.text.toLowerCase().split(' ');
    List<String> tags = _tagsController.text
        .toLowerCase()
        .split(',')
        .map((e) => e.trim())
        .toList();
    List<String> searchIndex = [...keywords, ...tags];
    searchIndex.removeWhere((e) => e.isEmpty);

    Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'price': int.tryParse(_priceController.text) ?? 0,
      'mrp': int.tryParse(_mrpController.text) ?? 0,
      'stock': int.tryParse(_stockController.text) ?? 0,
      'imageUrl': _heroImageUrl,
      'gallery': _galleryUrls,
      'description': _descController.text.trim(),
      'tags': tags,
      'search_keywords': searchIndex,
      'vendor_id': currentUser?.email,
      'isActive': true,
    };
    if (docId == null) {
      data['created_at'] = FieldValue.serverTimestamp();
    }

    if (docId == null) {
      await FirebaseFirestore.instance.collection('products').add(data);
    } else {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(docId)
          .update(data);
    }

    if (ctx.mounted) {
      Navigator.pop(ctx);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _mrpController.clear();
    _stockController.clear();
    _tagsController.clear();
    _descController.clear();
    _heroImageUrl = "";
    _galleryUrls = [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
        backgroundColor: Colors.orange[100],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('vendor_id', isEqualTo: currentUser?.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs
              .where(
                (d) =>
                    d['name'].toString().toLowerCase().contains(_searchQuery),
              )
              .toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading:
                      (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                          ? Image.network(
                              data['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.image),
                  title: Text(data['name']),
                  subtitle: Text(
                    "₹${data['price']} (MRP: ${data['mrp'] ?? 0})",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showProductDialog(
                      oldData: data,
                      docId: docs[index].id,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
