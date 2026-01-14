import 'package:flutter/material.dart';
import '../../utils/app_constants.dart';
import 'dart:async';

class GlobalSearchBar extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onMicTap;
  final bool readOnly;

  const GlobalSearchBar({
    super.key,
    this.onTap,
    this.onMicTap,
    this.readOnly = true,
  });

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  int _currentIndex = 0;
  Timer? _timer;
  
  final List<String> _placeholders = [
    'Search for products...',
    'Search potato, onion...',
    'Search biscuits, snacks...',
    'Search rice, wheat...',
    'Search milk, dairy...',
    'Search fruits, vegetables...',
    'Search beverages, drinks...',
    'Search personal care...',
  ];

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _placeholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
              child: widget.readOnly
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _placeholders[_currentIndex],
                        key: ValueKey<int>(_currentIndex),
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : const TextField(
                      decoration: InputDecoration(
                        hintText: AppConstants.searchPlaceholder,
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onMicTap,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.grey, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
