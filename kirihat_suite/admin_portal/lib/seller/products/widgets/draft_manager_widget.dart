import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kirihat_core/models/seller_model.dart';
import 'package:kirihat_core/services/seller_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../enhanced_add_product_screen.dart';

class DraftManagerWidget extends StatefulWidget {
  final SellerModel seller;

  const DraftManagerWidget({super.key, required this.seller});

  @override
  State<DraftManagerWidget> createState() => _DraftManagerWidgetState();
}

class _DraftManagerWidgetState extends State<DraftManagerWidget> {
  final SellerService _sellerService = SellerService();
  late Stream<QuerySnapshot> _draftsStream;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  void _loadDrafts() {
    // Re-assigning the stream triggers the StreamBuilder to re-subscribe
    _draftsStream = _sellerService.getAllProductDrafts(widget.seller.id);
  }

  void _refresh() {
    setState(() {
      _loadDrafts();
    });
  }

  // Format relative time
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String? _extractUrl(String text) {
    // Regex to find the Firestore console link
    final RegExp urlRegExp = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _draftsStream,
      builder: (context, snapshot) {
        // Handle errors
        if (snapshot.hasError) {
          final errorStr = snapshot.error.toString();
          final indexUrl = _extractUrl(errorStr);
          final isIndexError = errorStr.contains('requires an index') || indexUrl != null;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIndexError ? Icons.build_circle_outlined : Icons.error_outline,
                    size: 64, 
                    color: isIndexError ? Colors.orange : Colors.red[400]
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isIndexError ? 'Missing Database Index' : 'Error loading drafts',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (isIndexError) ...[
                    const Text(
                      'This query requires a Firestore index. Please create it to continue.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (indexUrl != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Create Index'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () => _launchUrl(indexUrl),
                      ),
                  ] else ...[
                    Text(
                      '$errorStr',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // Retry Button
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drafts_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No drafts saved',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save your product listings as drafts to resume later',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                 OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Check for updates'),
                  ),
              ],
            ),
          );
        }

        final drafts = snapshot.data!.docs.reversed.toList(); // Reverse to show newest first

        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
            // Wait a bit to simulate refresh as stream updates are instant if connected
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final data = draft.data() as Map<String, dynamic>?;
              
              // Safety checks
              if (data == null) return const SizedBox.shrink();
              
              final draftTitle = data['draft_title'] as String? ?? 'Untitled Draft';
              final draftData = data['draft_data'] as Map<String, dynamic>?;
              final category = draftData?['category'] as String? ?? 'No category';
              
              // Safe timestamp conversion
              DateTime? updatedAt;
              try {
                final timestamp = data['updated_at'];
                if (timestamp is Timestamp) {
                  updatedAt = timestamp.toDate();
                }
              } catch (e) {
                // Timestamp conversion failed, will show "Just now"
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    // Resume draft
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnhancedAddProductScreen(
                          seller: widget.seller,
                          draftId: draft.id,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.drafts,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Draft info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draftTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.category, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    updatedAt != null
                                        ? 'Updated ${_formatRelativeTime(updatedAt)}'
                                        : 'Just now',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Resume button
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.blue),
                              tooltip: 'Resume',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EnhancedAddProductScreen(
                                      seller: widget.seller,
                                      draftId: draft.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _showDeleteConfirmation(context, draft.id, draftTitle),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String draftId, String draftTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Text('Are you sure you want to delete "$draftTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _sellerService.deleteProductDraft(draftId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Draft deleted successfully'
                          : 'Failed to delete draft',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
