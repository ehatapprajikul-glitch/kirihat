import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_user_dialog.dart';
import 'user_details.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  String _sortColumn = 'name';
  bool _sortAscending = true;
  
  final int _rowsPerPage = 10;
  int _currentPage = 0;

  final List<String> _roles = ['All', 'Customer', 'Vendor', 'Rider', 'Admin'];
  final List<String> _statuses = ['All', 'Active', 'Disabled'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage all users, roles, and permissions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showCreateUserDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Statistics Cards
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            var allUsers = snapshot.data!.docs;
            int totalUsers = allUsers.length;
            int activeUsers = allUsers.where((doc) => !((doc.data() as Map)['disabled'] ?? false)).length;
            int disabledUsers = totalUsers - activeUsers;
            
            Map<String, int> roleCounts = {};
            for (var doc in allUsers) {
              String role = ((doc.data() as Map)['role'] ?? 'customer').toString().toLowerCase();
              roleCounts[role] = (roleCounts[role] ?? 0) + 1;
            }

            return Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Users',
                    value: totalUsers.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Active',
                    value: activeUsers.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Disabled',
                    value: disabledUsers.toString(),
                    icon: Icons.block,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Admins',
                    value: (roleCounts['admin'] ?? 0).toString(),
                    icon: Icons.admin_panel_settings,
                    color: Colors.purple,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Filters Row
        Row(
          children: [
            // Search
            Expanded(
              flex: 2,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                    _currentPage = 0; // Reset to first page on search
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0D9759), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Role Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _roleFilter,
                underline: const SizedBox(),
                hint: const Text('Role'),
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 8),
                        Text(role),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _roleFilter = value!;
                    _currentPage = 0;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),

            // Status Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                hint: const Text('Status'),
                items: _statuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(
                          status == 'Active' ? Icons.check_circle :
                          status == 'Disabled' ? Icons.block : Icons.filter_list,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(status),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value!;
                    _currentPage = 0;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Users Table
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              var users = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                
                // Search filter
                if (_searchQuery.isNotEmpty) {
                  String name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                  String email = (data['email'] ?? '').toString().toLowerCase();
                  String phone = (data['phone'] ?? data['phone_number'] ?? data['phoneNumber']).toString().toLowerCase();
                  if (phone == 'null') {
                      if (data['current_address'] != null && data['current_address'] is Map) {
                          phone = (data['current_address']['phone'] ?? '').toString().toLowerCase();
                      } else {
                          phone = '';
                      }
                  }
                  
                  if (!name.contains(_searchQuery) && 
                      !email.contains(_searchQuery) && 
                      !phone.contains(_searchQuery)) {
                    return false;
                  }
                }

                // Role filter
                if (_roleFilter != 'All') {
                  String role = (data['role'] ?? 'customer').toString();
                  if (role.toLowerCase() != _roleFilter.toLowerCase()) {
                    return false;
                  }
                }

                // Status filter
                if (_statusFilter != 'All') {
                  bool isDisabled = data['disabled'] ?? false;
                  if (_statusFilter == 'Active' && isDisabled) return false;
                  if (_statusFilter == 'Disabled' && !isDisabled) return false;
                }

                return true;
              }).toList();

              if (users.isEmpty) {
                return _buildNoResultsState();
              }

              // Sort users
              users.sort((a, b) {
                var aData = a.data() as Map<String, dynamic>;
                var bData = b.data() as Map<String, dynamic>;
                
                int comparison = 0;
                switch (_sortColumn) {
                  case 'name':
                    String aName = (aData['name'] ?? aData['displayName'] ?? '').toString();
                    String bName = (bData['name'] ?? bData['displayName'] ?? '').toString();
                    comparison = aName.compareTo(bName);
                    break;
                  case 'email':
                    String aEmail = (aData['email'] ?? '').toString();
                    String bEmail = (bData['email'] ?? '').toString();
                    comparison = aEmail.compareTo(bEmail);
                    break;
                  case 'role':
                    String aRole = (aData['role'] ?? 'customer').toString();
                    String bRole = (bData['role'] ?? 'customer').toString();
                    comparison = aRole.compareTo(bRole);
                    break;
                  case 'status':
                    bool aDisabled = aData['disabled'] ?? false;
                    bool bDisabled = bData['disabled'] ?? false;
                    comparison = aDisabled.toString().compareTo(bDisabled.toString());
                    break;
                }
                
                return _sortAscending ? comparison : -comparison;
              });

              // Pagination
              int totalPages = (users.length / _rowsPerPage).ceil();
              int startIndex = _currentPage * _rowsPerPage;
              int endIndex = (startIndex + _rowsPerPage).clamp(0, users.length);
              var paginatedUsers = users.sublist(startIndex, endIndex);

              return Column(
                children: [
                  Container(
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
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                          dataRowHeight: 60,
                          headingRowHeight: 56,
                          columnSpacing: 40,
                          columns: [
                            DataColumn(
                              label: const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumn = 'name';
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumn = 'email';
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            const DataColumn(
                              label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            DataColumn(
                              label: const Text('Role', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumn = 'role';
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            DataColumn(
                              label: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (columnIndex, ascending) {
                                setState(() {
                                  _sortColumn = 'status';
                                  _sortAscending = ascending;
                                });
                              },
                            ),
                            const DataColumn(
                              label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                          rows: paginatedUsers.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            String uid = doc.id;
                            
                            String name = data['name'] ?? data['displayName'] ?? 'N/A';
                            String email = data['email'] ?? 'N/A';
                            var phone = data['phone'] ?? data['phone_number'] ?? data['phoneNumber'];
                            if (phone == null && data['current_address'] != null && data['current_address'] is Map) {
                              phone = data['current_address']['phone'];
                            }
                            String displayPhone = (phone ?? '').toString();
                            if (displayPhone.isEmpty || displayPhone == 'null') displayPhone = 'N/A';
                            String role = (data['role'] ?? 'customer').toString();
                            bool isDisabled = data['disabled'] ?? false;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: const Color(0xFF0D9759).withOpacity(0.1),
                                        child: Text(
                                          name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF0D9759),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            'ID: ${uid.substring(0, 8)}...',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(email),
                                    ],
                                  ),
                                ),
                                  DataCell(
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          displayPhone != 'N/A' ? displayPhone : 'N/A',
                                          style: TextStyle(
                                            color: displayPhone != 'N/A' ? Colors.black87 : Colors.grey,
                                            fontStyle: displayPhone != 'N/A' ? FontStyle.normal : FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                DataCell(_buildRoleBadge(role)),
                                DataCell(_buildStatusBadge(isDisabled)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ActionButton(
                                        icon: Icons.visibility_outlined,
                                        tooltip: 'View Details',
                                        color: Colors.blue,
                                        onPressed: () => _showUserDetails(uid, data),
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionButton(
                                        icon: Icons.edit_outlined,
                                        tooltip: 'Edit',
                                        color: Colors.orange,
                                        onPressed: () => _showEditUserDialog(uid, data),
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionButton(
                                        icon: isDisabled ? Icons.check_circle_outline : Icons.block_outlined,
                                        tooltip: isDisabled ? 'Enable' : 'Disable',
                                        color: isDisabled ? Colors.green : Colors.grey,
                                        onPressed: () => _toggleUserStatus(uid, isDisabled),
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionButton(
                                        icon: Icons.delete_outline,
                                        tooltip: 'Delete',
                                        color: Colors.red,
                                        onPressed: () => _deleteUser(uid, name),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  
                  // Pagination Controls
                  const SizedBox(height: 16),
                  _buildPaginationControls(users.length, totalPages),
                ],
              );
            },
          ),

      ],
    ));
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    int startItem = _currentPage * _rowsPerPage + 1;
    int endItem = ((_currentPage + 1) * _rowsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalItems users',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous page',
              ),
              const SizedBox(width: 8),
              ...List.generate(totalPages, (index) {
                if (totalPages <= 5 ||
                    index == 0 ||
                    index == totalPages - 1 ||
                    (index >= _currentPage - 1 && index <= _currentPage + 1)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _currentPage = index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF0D9759)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentPage == index
                                ? const Color(0xFF0D9759)
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: _currentPage == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (index == _currentPage - 2 || index == _currentPage + 2) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: Colors.grey[600])),
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
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
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading users...'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first user to get started',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateUserDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No matching users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _roleFilter = 'All';
                  _statusFilter = 'All';
                  _currentPage = 0;
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
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

  Widget _buildStatusBadge(bool isDisabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDisabled ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDisabled ? Icons.block : Icons.check_circle,
            size: 14,
            color: isDisabled ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 6),
          Text(
            isDisabled ? 'DISABLED' : 'ACTIVE',
            style: TextStyle(
              color: isDisabled ? Colors.red : Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateUserDialog(),
    );
  }

  void _showEditUserDialog(String uid, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => CreateUserDialog(uid: uid, initialData: data),
    );
  }

  void _showUserDetails(String uid, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => UserDetails(uid: uid, userData: data),
    );
  }

  Future<void> _toggleUserStatus(String uid, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'disabled': !currentStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  currentStatus ? Icons.check_circle : Icons.block,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(currentStatus ? 'User enabled successfully' : 'User disabled successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String uid, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Deletion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete user "$name"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('User deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }
}

// Statistics Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}