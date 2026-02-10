import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserDetails extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const UserDetails({
    super.key,
    required this.uid,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9759).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF0D9759),
                    child: Text(
                      (userData['name'] ?? userData['displayName'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['name'] ?? userData['displayName'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildRoleBadge(userData['role'] ?? 'customer'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Information Section
                    _buildSection(
                      'Account Information',
                      Icons.account_circle,
                      [
                        _buildInfoRow('User ID', uid, canCopy: true),
                        _buildInfoRow('Email', userData['email'] ?? 'N/A', canCopy: true),
                        _buildInfoRow('Phone', () {
                          var p = userData['phone'] ?? userData['phone_number'] ?? userData['phoneNumber'];
                          if (p == null && userData['current_address'] != null && userData['current_address'] is Map) {
                            p = userData['current_address']['phone'];
                          }
                          return p ?? 'N/A';
                        }(), canCopy: true),
                        _buildInfoRow('Role', (userData['role'] ?? 'customer').toString().toUpperCase()),
                        _buildInfoRow(
                          'Status',
                          (userData['disabled'] ?? false) ? 'Disabled' : 'Active',
                          valueColor: (userData['disabled'] ?? false) ? Colors.red : Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Additional Details Section
                    _buildSection(
                      'Additional Details',
                      Icons.info_outline,
                      [
                        if (userData['address'] != null)
                          _buildInfoRow('Address', userData['address']),
                        if (userData['city'] != null)
                          _buildInfoRow('City', userData['city']),
                        if (userData['state'] != null)
                          _buildInfoRow('State', userData['state']),
                        if (userData['zipCode'] != null)
                          _buildInfoRow('Zip Code', userData['zipCode']),
                        if (userData['country'] != null)
                          _buildInfoRow('Country', userData['country']),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Timestamps Section
                    _buildSection(
                      'Timestamps',
                      Icons.schedule,
                      [
                        _buildInfoRow(
                          'Created At',
                          _formatTimestamp(userData['created_at'] ?? userData['createdAt']),
                        ),
                        _buildInfoRow(
                          'Last Updated',
                          _formatTimestamp(userData['updated_at'] ?? userData['updatedAt']),
                        ),
                        if (userData['last_login'] != null)
                          _buildInfoRow(
                            'Last Login',
                            _formatTimestamp(userData['last_login']),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Account Settings Section
                    if (userData['email_verified'] != null || 
                        userData['phone_verified'] != null || 
                        userData['two_factor_enabled'] != null)
                      Column(
                        children: [
                          _buildSection(
                            'Security',
                            Icons.security,
                            [
                              if (userData['email_verified'] != null)
                                _buildInfoRow(
                                  'Email Verified',
                                  userData['email_verified'] ? 'Yes' : 'No',
                                  valueColor: userData['email_verified'] ? Colors.green : Colors.orange,
                                ),
                              if (userData['phone_verified'] != null)
                                _buildInfoRow(
                                  'Phone Verified',
                                  userData['phone_verified'] ? 'Yes' : 'No',
                                  valueColor: userData['phone_verified'] ? Colors.green : Colors.orange,
                                ),
                              if (userData['two_factor_enabled'] != null)
                                _buildInfoRow(
                                  '2FA Enabled',
                                  userData['two_factor_enabled'] ? 'Yes' : 'No',
                                  valueColor: userData['two_factor_enabled'] ? Colors.green : Colors.grey,
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                    // Custom Fields Section
                    if (_hasCustomFields())
                      Column(
                        children: [
                          _buildSection(
                            'Custom Fields',
                            Icons.extension,
                            _buildCustomFields(),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                    // Raw Data (for debugging)
                    ExpansionTile(
                      title: const Text('Raw Data (Debug)'),
                      leading: const Icon(Icons.code),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            userData.toString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0D9759)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool canCopy = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      color: valueColor ?? Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (canCopy && value != 'N/A')
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                    },
                    tooltip: 'Copy to clipboard',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    IconData icon;
    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        break;
      case 'vendor':
        color = Colors.blue;
        icon = Icons.store;
        break;
      case 'rider':
        color = Colors.orange;
        icon = Icons.delivery_dining;
        break;
      default:
        color = Colors.green;
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }
      
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  bool _hasCustomFields() {
    final standardFields = [
      'name', 'displayName', 'email', 'phone', 'phone_number', 'phoneNumber',
      'role', 'disabled', 'address', 'city', 'state', 'zipCode', 'country',
      'created_at', 'createdAt', 'updated_at', 'updatedAt', 'last_login',
      'email_verified', 'phone_verified', 'two_factor_enabled',
    ];

    return userData.keys.any((key) => !standardFields.contains(key));
  }

  List<Widget> _buildCustomFields() {
    final standardFields = [
      'name', 'displayName', 'email', 'phone', 'phone_number', 'phoneNumber',
      'role', 'disabled', 'address', 'city', 'state', 'zipCode', 'country',
      'created_at', 'createdAt', 'updated_at', 'updatedAt', 'last_login',
      'email_verified', 'phone_verified', 'two_factor_enabled',
    ];

    return userData.entries
        .where((entry) => !standardFields.contains(entry.key))
        .map((entry) {
          return _buildInfoRow(
            entry.key,
            entry.value.toString(),
            canCopy: true,
          );
        })
        .toList();
  }
}