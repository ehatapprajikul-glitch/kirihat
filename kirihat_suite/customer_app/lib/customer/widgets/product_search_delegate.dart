import 'package:flutter/material.dart';
import 'package:kirihat_core/utils/cart_helper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'draggable_cart_wrapper.dart';
import '../../widgets/product_card.dart';
import '../product/enhanced_product_detail.dart';
import '../services/search_service.dart';
import 'dart:async';

class ProductSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> products; // Local products (if category specific)
  final String? categoryName;
  final SearchService _searchService = SearchService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  Timer? _debounce;
  
  // Cache for search results to avoid flickering
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  final bool autoStartListening;
  bool _hasAutoStarted = false;

  ProductSearchDelegate({
    this.products = const [],
    this.categoryName,
    String? initialQuery,
    this.autoStartListening = false,
  }) {
    if (initialQuery != null) {
      query = initialQuery;
    }
  }

  /// Toggle voice listener
  Future<void> _listen(BuildContext context, Function(String) onResult) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('Mic status: $status'),
        onError: (errorNotification) => debugPrint('Mic error: $errorNotification'),
      );
      if (available) {
        _isListening = true;
        _speech.listen(
          onResult: (val) {
             query = val.recognizedWords;
             if (val.finalResult) {
               _isListening = false;
               _speech.stop();
               showResults(context);
             }
             onResult(query);
          },
        );
      }
    } else {
      _isListening = false;
      _speech.stop();
    }
  }

  @override
  String get searchFieldLabel => categoryName != null 
      ? 'Search in $categoryName...' 
      : 'Search products, categories...';

  @override
  List<Widget> buildActions(BuildContext context) {
    // Auto-start listening if requested and not yet done
    if (autoStartListening && !_hasAutoStarted) {
      _hasAutoStarted = true;
       // Schedule listen after build
       Future.microtask(() => _listen(context, (val) {
         // Rebuild handled by setStates inside internal logic or delegate
       }));
    }

    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      IconButton(
        icon: Icon(_isListening ? Icons.mic : Icons.mic_none, 
          color: _isListening ? Colors.red : null),
        onPressed: () {
          // Trigger listener and rebuild to show active state
          _listen(context, (val) {
            // Force rebuild to show query update? 
            // SearchDelegate handles query updates automatically usually
          });
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Save search if not empty
    if (query.trim().isNotEmpty) {
      _searchService.saveSearch(query);
    }

    // Determine source of data
    // If local products are provided, search them
    Future<List<Map<String, dynamic>>> resultsFuture;
    
    if (products.isNotEmpty) {
      final searchLower = query.toLowerCase();
      final localResults = products.where((product) {
        // Search across multiple fields
        final name = (product['name'] ?? '').toString().toLowerCase();
        if (name.contains(searchLower)) return true;
        
        final category = (product['category'] ?? '').toString().toLowerCase();
        if (category.contains(searchLower)) return true;
        
        final subcategory = (product['subcategory'] ?? '').toString().toLowerCase();
        if (subcategory.contains(searchLower)) return true;
        
        final brand = (product['brand'] ?? '').toString().toLowerCase();
        if (brand.contains(searchLower)) return true;
        
        // Keywords array
        final keywords = product['keywords'];
        if (keywords is List) {
          for (var keyword in keywords) {
            if (keyword.toString().toLowerCase().contains(searchLower)) {
              return true;
            }
          }
        }
        
        // Tags array
        final tags = product['tags'];
        if (tags is List) {
          for (var tag in tags) {
            if (tag.toString().toLowerCase().contains(searchLower)) {
              return true;
            }
          }
        }
        
        return false;
      }).toList();
      resultsFuture = Future.value(localResults);
    } else {
      // Global search
      resultsFuture = _searchService.searchProducts(query);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No products found for "$query"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data!;

        return DraggableCartWrapper(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final product = results[index];
              return ProductCard(
                product: product,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EnhancedProductDetailScreen(
                        productId: product['id'],
                        productData: product,
                      ),
                    ),
                  );
                },
                onAdd: () async {
                  await CartHelper.addToCart(context, product, showSuccessMessage: false);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      // Show History
      return FutureBuilder<List<String>>(
        future: _searchService.getRecentSearches(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent searches',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final term = snapshot.data![index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(term),
                trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
                onTap: () {
                  query = term;
                  showResults(context);
                },
              );
            },
          );
        },
      );
    }

    // Autocomplete / Live Search
    // If we have local products, filter them
    if (products.isNotEmpty) {
      final suggestions = products.where((product) {
        final name = (product['name'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
      
      return ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final product = suggestions[index];
          return ListTile(
            leading: ClipRRect(
               borderRadius: BorderRadius.circular(4),
               child: product['imageUrl'] != null
                   ? Image.network(product['imageUrl'], width: 40, height: 40, fit: BoxFit.cover,
                       errorBuilder: (_,__,___) => const Icon(Icons.image))
                   : const Icon(Icons.image),
            ),
            title: Text(product['name'] ?? 'Unknown'),
            subtitle: Text(product['category'] ?? ''),
            onTap: () {
              query = product['name'];
              showResults(context);
            },
          );
        },
      );
    }
    
    // Global Autocomplete (using SearchService)
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchService.searchProducts(query), // Already minimal/optimized
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final suggestions = snapshot.data!;
        
        if (suggestions.isEmpty) {
          return const ListTile(
             title: Text('Searching...'),
             leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final product = suggestions[index];
            return ListTile(
              leading: ClipRRect(
                 borderRadius: BorderRadius.circular(4),
                 child: product['imageUrl'] != null
                     ? Image.network(product['imageUrl'], width: 40, height: 40, fit: BoxFit.cover,
                         errorBuilder: (_,__,___) => const Icon(Icons.image))
                     : const Icon(Icons.search, color: Colors.grey),
              ),
              title: Text(product['name'] ?? ''),
              subtitle: Text(product['category'] ?? ''),
              onTap: () {
                query = product['name'];
                showResults(context);
              },
            );
          },
        );
      },
    );
  }
}
