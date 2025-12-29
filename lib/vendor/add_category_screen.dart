import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameController = TextEditingController();
  XFile? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = image);
  }

  Future<String?> _uploadToCloudinary(XFile image) async {
    try {
      var uri =
          Uri.parse("https://api.cloudinary.com/v1_1/du634o3sf/image/upload");
      var request = http.MultipartRequest("POST", uri);
      Uint8List bytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: "category.jpg"));
      request.fields['upload_preset'] = "ouofgw7n";
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var jsonMap = jsonDecode(String.fromCharCodes(responseData));
        return jsonMap['secure_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveCategory() async {
    if (_nameController.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name and Icon are required")));
      return;
    }

    setState(() => _isLoading = true);

    String? imageUrl = await _uploadToCloudinary(_imageFile!);

    if (imageUrl != null) {
      await FirebaseFirestore.instance.collection('categories').add({
        'name': _nameController.text.trim(),
        'icon': imageUrl, // Now a URL, not an emoji
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Upload Failed")));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add New Category"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: _imageFile != null
                  ? (kIsWeb
                      ? NetworkImage(_imageFile!.path)
                      : FileImage(File(_imageFile!.path)) as ImageProvider)
                  : null,
              child: _imageFile == null
                  ? const Icon(Icons.add_a_photo, size: 30)
                  : null,
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: "Category Name", border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCategory,
          child: _isLoading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator())
              : const Text("Add"),
        ),
      ],
    );
  }
}
