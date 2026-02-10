import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationManager extends StatefulWidget {
  const NotificationManager({super.key});

  @override
  State<NotificationManager> createState() => _NotificationManagerState();
}

class _NotificationManagerState extends State<NotificationManager> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userIdController = TextEditingController();
  
  bool _isSending = false;
  String _targetType = 'all'; // 'all' or 'specific'

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final notificationData = {
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'target_type': _targetType,
        'target_user_id': _targetType == 'specific' ? _userIdController.text.trim() : null,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending', // A Cloud Function or background service should pick this up
        'is_read': false,
      };

      // 1. Add to global 'notifications' collection for triggering cloud functions
      await FirebaseFirestore.instance.collection('admin_notifications').add(notificationData);
      
      // 2. If it's a specific user, we can also add it directly to their subcollection for immediate UI update
      // This ensures they see it even if the push notification service is slow
      if (_targetType == 'specific') {
         final userId = _userIdController.text.trim();
         if (userId.isNotEmpty) {
           await FirebaseFirestore.instance
               .collection('users')
               .doc(userId)
               .collection('notifications')
               .add(notificationData);
         }
      } else if (_targetType == 'all') {
         // distinct 'broadcasts' collection that apps listen to?
         // Or rely on Cloud Function to fan-out.
         // For now, we assume Cloud Function handles fan-out or topic messaging.
         await FirebaseFirestore.instance.collection('broadcast_notifications').add(notificationData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification Sent!')),
        );
        _titleController.clear();
        _bodyController.clear();
        _userIdController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Manager')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Enter body' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(labelText: 'Target', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                  DropdownMenuItem(value: 'specific', child: Text('Specific User')),
                ],
                onChanged: (val) => setState(() => _targetType = val!),
              ),
              if (_targetType == 'specific') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _userIdController,
                  decoration: const InputDecoration(labelText: 'User ID (UID)', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Enter User UID' : null,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSending 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Send Notification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
