import 'package:flutter/material.dart';

class GlobalSearchBar extends StatelessWidget {
  final VoidCallback? onTap;
  final bool readOnly;

  const GlobalSearchBar({
    super.key,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: readOnly
                  ? const Text(
                      'Search bar',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    )
                  : const TextField(
                      decoration: InputDecoration(
                        hintText: 'Search bar',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mic, color: Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
