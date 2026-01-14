import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/category_template_seeder.dart';

/// One-time initialization script to set up the product listing enhancement system
/// Run this once after deploying the new code to populate category templates
class SystemInitializationScreen extends StatefulWidget {
  const SystemInitializationScreen({super.key});

  @override
  State<SystemInitializationScreen> createState() => _SystemInitializationScreenState();
}

class _SystemInitializationScreenState extends State<SystemInitializationScreen> {
  bool _isInitializing = false;
  final List<String> _logs = [];
  bool _isComplete = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Initialization'),
        backgroundColor: const Color(0xFF34A853),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Listing Enhancement Setup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'This will initialize:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('• Category specification templates (5 categories)'),
                  const Text('• Electronics (Smartphones, Laptops)'),
                  const Text('• Grocery (Packaged Foods)'),
                  const Text('• Fashion (Mens Clothing)'),
                  const Text('• Home & Kitchen (Cookware)'),
                  const Text('• Beauty (Skincare)'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (!_isComplete && !_isInitializing)
              ElevatedButton.icon(
                onPressed: _initializeSystem,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Initialize System'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34A853),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),

            if (_isInitializing)
              const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Initializing...', style: TextStyle(fontSize: 16)),
                ],
              ),

            if (_isComplete)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Initialization Complete! You can now test the product listing system.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            
            if (_logs.isNotEmpty) ...[
              const Text(
                'Logs:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Expanded(
                              child: Text(_logs[index]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _initializeSystem() async {
    setState(() {
      _isInitializing = true;
      _logs.clear();
    });

    try {
      _addLog('Starting system initialization...');
      
      // Get current admin user ID
      String? adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) {
        _addLog('ERROR: No authenticated user found');
        return;
      }
      
      _addLog('Admin ID: $adminId');
      
      // Initialize the seeder
      _addLog('Initializing category template seeder...');
      final seeder = CategoryTemplateSeeder();
      
      // Seed all templates
      _addLog('Seeding category templates...');
      await seeder.seedAllTemplates(adminId);
      
      _addLog('✓ Electronics category templates created');
      _addLog('  - Smartphones (12 specification fields)');
      _addLog('  - Laptops (11 specification fields)');
      
      _addLog('✓ Grocery category templates created');
      _addLog('  - Packaged Foods (11 specification fields)');
      
      _addLog('✓ Fashion category templates created');
      _addLog('  - Mens Clothing (9 specification fields)');
      
      _addLog('✓ Home & Kitchen category templates created');
      _addLog('  - Cookware (8 specification fields)');
      
      _addLog('✓ Beauty category templates created');
      _addLog('  - Skincare (10 specification fields)');
      
      _addLog('');
      _addLog('✅ All templates seeded successfully!');
      _addLog('');
      _addLog('Next steps:');
      _addLog('1. Update navigation to use EnhancedAddProductScreen');
      _addLog('2. Add admin menu items for specification manager');
      _addLog('3. Test seller product submission flow');
      
      setState(() {
        _isComplete = true;
      });

    } catch (e) {
      _addLog('ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: $e')),
      );
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }
}
