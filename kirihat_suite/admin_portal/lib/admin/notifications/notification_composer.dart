import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_history.dart';

class NotificationComposer extends StatefulWidget {
  const NotificationComposer({super.key});

  @override
  State<NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends State<NotificationComposer> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userIdController = TextEditingController(); 
  final _imageController = TextEditingController(); // Added
  
  String _targetType = 'all';
  String _roleFilter = 'customer';
  String _notificationType = 'general'; // Added
  bool _hasCart = false;
  bool _hasWishlist = false;
  String? _categoryFilter;
  bool _isSending = false;

  int _estimatedReach = 0;

  @override
  void initState() {
    super.initState();
    _calculateReach();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _userIdController.dispose();
    _imageController.dispose(); // Added
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Send notifications to users based on activity and preferences',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('View History'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Composer Form
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Notification Title *',
                              hintText: 'e.g., Flash Sale Alert!',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Body
                          TextFormField(
                            controller: _bodyController,
                            decoration: const InputDecoration(
                              labelText: 'Message *',
                              hintText: 'e.g., Get 50% off on fresh fruits today!',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Message is required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),
                          
                          // Image URL
                          TextFormField(
                            controller: _imageController, // Need to define
                            decoration: const InputDecoration(
                              labelText: 'Image URL (Optional)',
                              hintText: 'https://example.com/image.jpg',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.image),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Notification Type
                          DropdownButtonFormField<String>(
                             value: _notificationType, // Need to define
                             decoration: const InputDecoration(
                                labelText: 'Notification Type',
                                border: OutlineInputBorder(),
                             ),
                             items: const [
                                DropdownMenuItem(value: 'general', child: Text('General Message')),
                                DropdownMenuItem(value: 'arrival', child: Text('New Arrival')),
                                DropdownMenuItem(value: 'offer', child: Text('Special Offer')),
                             ],
                             onChanged: (val) => setState(() => _notificationType = val!),
                          ),

                          const SizedBox(height: 24),

                          // Target Selection
                          const Text(
                            'Target Audience',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _targetType,
                            decoration: const InputDecoration(
                              labelText: 'Send To',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Users')),
                              DropdownMenuItem(value: 'role', child: Text('By Role')),
                              DropdownMenuItem(value: 'activity', child: Text('By Activity')),
                              DropdownMenuItem(value: 'specific', child: Text('Specific User')), // Added option
                            ],
                            onChanged: (value) {
                              setState(() {
                                _targetType = value!;
                                _calculateReach();
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Specific User Input
                          if (_targetType == 'specific') ...[
                             TextFormField(
                               controller: _userIdController, // Need to define this controller
                               decoration: const InputDecoration(
                                 labelText: 'User ID (UID)',
                                 hintText: 'Paste user UID here',
                                 border: OutlineInputBorder(),
                               ),
                               validator: (value) {
                                  if (_targetType == 'specific' && (value == null || value.trim().isEmpty)) {
                                     return 'User UID is required';
                                  }
                                  return null;
                               },
                               onChanged: (_) => _calculateReach(),
                             ),
                             const SizedBox(height: 16),
                          ],

                          const SizedBox(height: 16),

                          // Role Filter
                          if (_targetType == 'role') ...[
                            DropdownButtonFormField<String>(
                              value: _roleFilter,
                              decoration: const InputDecoration(
                                labelText: 'User Role',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'customer', child: Text('Customers')),
                                DropdownMenuItem(value: 'vendor', child: Text('Vendors')),
                                DropdownMenuItem(value: 'rider', child: Text('Riders')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _roleFilter = value!;
                                  _calculateReach();
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Activity Filters
                          if (_targetType == 'activity') ...[
                            CheckboxListTile(
                              title: const Text('Has items in cart'),
                              value: _hasCart,
                              onChanged: (value) {
                                setState(() {
                                  _hasCart = value!;
                                  _calculateReach();
                                });
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Has items in wishlist'),
                              value: _hasWishlist,
                              onChanged: (value) {
                                setState(() {
                                  _hasWishlist = value!;
                                  _calculateReach();
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Estimated Reach
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9759).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF0D9759).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Color(0xFF0D9759)),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estimated Reach',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '$_estimatedReach users',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D9759),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Send Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSending ? null : _sendNotification,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(_isSending ? 'SENDING...' : 'SEND NOTIFICATION'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9759),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Preview Panel
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9759),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kiri Hat',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'now',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _titleController.text.isEmpty
                                  ? 'Notification Title'
                                  : _titleController.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _bodyController.text.isEmpty
                                  ? 'Your notification message will appear here...'
                                  : _bodyController.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _calculateReach() async {
    try {
      if (_targetType == 'specific') {
         setState(() {
           _estimatedReach = _userIdController.text.trim().isNotEmpty ? 1 : 0;
         });
         return;
      }

      Query query = FirebaseFirestore.instance.collection('users');

      if (_targetType == 'role') {
        query = query.where('role', isEqualTo: _roleFilter);
      }

      var snapshot = await query.get();
      setState(() {
        _estimatedReach = snapshot.docs.length;
      });
    } catch (e) {
      setState(() => _estimatedReach = 0);
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      User? admin = FirebaseAuth.instance.currentUser;
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Save to notification history (Master Record)
      final DocumentReference historyRef = FirebaseFirestore.instance.collection('push_notifications').doc();
      
      final notificationData = {
        'id': historyRef.id,
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'target_type': _targetType,
        'target_role': _targetType == 'role' ? _roleFilter : null,
        'target_user_id': _targetType == 'specific' ? _userIdController.text.trim() : null,
        'filters': {
          'has_cart': _targetType == 'activity' ? _hasCart : null,
          'has_wishlist': _targetType == 'activity' ? _hasWishlist : null,
        },
        'sent_count': _estimatedReach,
        'created_by': admin?.uid,
        'created_by_email': admin?.email,
        'sent_at': FieldValue.serverTimestamp(),
        'status': 'sent',
        // Updated payload
        'type': _notificationType, 
        'image': _imageController.text.trim().isEmpty ? null : _imageController.text.trim(),
      };

      batch.set(historyRef, notificationData);

      // --- DISTRIBUTE TO USERS ---
      
      if (_targetType == 'specific') {
         // Specific User
         final targetUid = _userIdController.text.trim();
         if (targetUid.isNotEmpty) {
            final userNotifRef = FirebaseFirestore.instance
               .collection('users')
               .doc(targetUid)
               .collection('notifications')
               .doc();
               
            batch.set(userNotifRef, {
               ...notificationData,
               'is_read': false,
               'timestamp': FieldValue.serverTimestamp(),
            });
         }
         await batch.commit();
         
      } else {
         // ... (rest of batch logic remains same) ...
         // Broadcast (All / Role)
         Query userQuery = FirebaseFirestore.instance.collection('users');
         
         if (_targetType == 'role') {
            userQuery = userQuery.where('role', isEqualTo: _roleFilter);
         }
         
         final userSnapshot = await userQuery.get();
         
         // Commit the history record first
         await historyRef.set(notificationData); 
         
         // Now process users in batches of 400
         List<WriteBatch> batches = [];
         WriteBatch currentBatch = FirebaseFirestore.instance.batch();
         int operationCount = 0;
         
         for (var userDoc in userSnapshot.docs) {
             final userNotifRef = userDoc.reference.collection('notifications').doc();
             currentBatch.set(userNotifRef, {
                ...notificationData,
                'is_read': false,
                'timestamp': FieldValue.serverTimestamp(),
             });
             
             operationCount++;
             
             if (operationCount >= 400) {
                batches.add(currentBatch);
                currentBatch = FirebaseFirestore.instance.batch();
                operationCount = 0;
             }
         }
         
         if (operationCount > 0) {
            batches.add(currentBatch);
         }
         
         for (var b in batches) {
            await b.commit();
         }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to $_estimatedReach users!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _titleController.clear();
        _bodyController.clear();
        _imageController.clear(); // Clear image
        setState(() {
          _targetType = 'all';
          _notificationType = 'general'; // Reset type
          _hasCart = false;
          _hasWishlist = false;
        });
        _calculateReach();
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const Dialog(
        child: SizedBox(
          width: 800,
          height: 600,
          child: NotificationHistory(),
        ),
      ),
    );
  }
}
