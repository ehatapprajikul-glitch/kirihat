// Placeholder - The actual add product screen will be implemented later
// For now, show a simple message directing users to use the seller product screen

import 'package:flutter/material.dart';

class AddProductDialog extends StatelessWidget {
  const AddProductDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: const Text(
        'Product management will be available soon.\n\n'
        'For now, please use the master catalog browser to list products.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
