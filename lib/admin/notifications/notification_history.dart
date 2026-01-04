import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHistory extends StatelessWidget {
  const NotificationHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF0D9759)),
              const SizedBox(width: 12),
              const Text(
                'Notification History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('push_notifications')
                  .orderBy('sent_at', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No notifications sent yet'));
                }

                return ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String title = data['title'] ?? '';
                    String body = data['body'] ?? '';
                    int sentCount = data['sent_count'] ?? 0;
                    String targetType = data['target_type'] ?? 'all';
                    Timestamp? sentAt = data['sent_at'];

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0D9759),
                        child: Icon(Icons.notifications, color: Colors.white),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '$sentCount users • ${_formatTargetType(targetType)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (sentAt != null) ...[
                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                                Text(
                                  _formatDate(sentAt),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTargetType(String type) {
    switch (type) {
      case 'all':
        return 'All users';
      case 'role':
        return 'By role';
      case 'activity':
        return 'By activity';
      default:
        return type;
    }
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
