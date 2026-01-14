import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'level_fix_script.dart';

/// Migration script to convert old 2-level category/subcategory structure
/// to new unified hierarchical category system
class CategoryMigrationScript {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Run the complete migration
  Future<MigrationResult> runMigration(BuildContext context) async {
    final result = MigrationResult();

    try {
      // Step 1: Check if migration already done
      final newCategoriesQuery = await _firestore
          .collection('categories')
          .where('level', isGreaterThanOrEqualTo: 0)
          .limit(1)
          .get();

      if (newCategoriesQuery.docs.isNotEmpty) {
        // Check if has 'level' field - indicates new structure
        final firstDoc = newCategoriesQuery.docs.first.data();
        if (firstDoc.containsKey('level') && firstDoc.containsKey('parent_id')) {
          result.alreadyMigrated = true;
          result.message = 'Categories already migrated to new structure';
          return result;
        }
      }

      // Step 2: Backup (export to lists)
      result.message = 'Backing up data...';
      final oldCategories = await _firestore.collection('categories').get();
      final oldSubcategories = await _firestore.collection('subcategories').get();

      result.oldCategoriesCount = oldCategories.docs.length;
      result.oldSubcategoriesCount = oldSubcategories.docs.length;

      // Step 3: Migrate Categories (Root Level)
      result.message = 'Migrating root categories...';
      final categoryIdMap = <String, String>{}; // old ID -> new ID

      for (var doc in oldCategories.docs) {
        final oldData = doc.data();
        final newDocRef = await _firestore.collection('categories').add({
          'name': oldData['name'],
          'icon': oldData['icon'],
          'parent_id': null,
          'level': 0,
          'path': <String>[],
          'path_names': <String>[],
          'sort_order': oldData['sort_order'] ?? 0,
          'created_at': oldData['created_at'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'isActive': true,
          '_migrated_from_old_id': doc.id, // Keep reference for debugging
        });

        categoryIdMap[doc.id] = newDocRef.id;
        result.migratedRootCategories++;
      }

      // Step 4: Migrate Subcategories (Level 1)
      result.message = 'Migrating subcategories...';
      final subcategoryIdMap = <String, String>{}; // old subcategory ID -> new ID

      for (var doc in oldSubcategories.docs) {
        final oldData = doc.data();
        final oldCategoryId = oldData['category_id'] as String?;

        if (oldCategoryId == null || !categoryIdMap.containsKey(oldCategoryId)) {
          result.skippedSubcategories++;
          result.errors.add('Subcategory "${oldData['name']}" has invalid category_id: $oldCategoryId');
          continue;
        }

        final newParentId = categoryIdMap[oldCategoryId]!;

        // Get parent to build path
        final parentDoc = await _firestore.collection('categories').doc(newParentId).get();
        final parentData = parentDoc.data()!;
        final parentName = parentData['name'] as String;

        final newDocRef = await _firestore.collection('categories').add({
          'name': oldData['name'],
          'icon': oldData['icon_url'],
          'parent_id': newParentId,
          'level': 1,
          'path': [newParentId],
          'path_names': [parentName],
          'sort_order': oldData['position'] ?? 0,
          'created_at': oldData['created_at'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'isActive': true,
          '_migrated_from_old_subcategory_id': doc.id,
        });

        subcategoryIdMap[doc.id] = newDocRef.id;
        result.migratedSubcategories++;
      }

      // Step 5: Update Products
      result.message = 'Updating products...';
      final products = await _firestore.collection('master_products').get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (var productDoc in products.docs) {
        final productData = productDoc.data();
        final categoryName = productData['category'] as String?;
        final subcategoryName = productData['subcategory'] as String?;

        String? newCategoryId;
        List<String> categoryPath = [];
        List<String> categoryPathNames = [];

        // Try to find by subcategory first (more specific)
        if (subcategoryName != null && subcategoryName.isNotEmpty) {
          // Find subcategory by name and parent
          final subcategoryQuery = await _firestore
              .collection('categories')
              .where('name', isEqualTo: subcategoryName)
              .where('level', isEqualTo: 1)
              .limit(1)
              .get();

          if (subcategoryQuery.docs.isNotEmpty) {
            final subcategoryDoc = subcategoryQuery.docs.first;
            final subcategoryData = subcategoryDoc.data();
            newCategoryId = subcategoryDoc.id;
            categoryPath = List<String>.from(subcategoryData['path'] ?? []);
            categoryPath.add(newCategoryId!);
            categoryPathNames = List<String>.from(subcategoryData['path_names'] ?? []);
            categoryPathNames.add(subcategoryData['name']);
          }
        }

        // If no subcategory match, use category
        if (newCategoryId == null && categoryName != null && categoryName.isNotEmpty) {
          final categoryQuery = await _firestore
              .collection('categories')
              .where('name', isEqualTo: categoryName)
              .where('level', isEqualTo: 0)
              .limit(1)
              .get();

          if (categoryQuery.docs.isNotEmpty) {
            final categoryDoc = categoryQuery.docs.first;
            newCategoryId = categoryDoc.id;
            categoryPath = [newCategoryId!];
            categoryPathNames = [categoryName];
          }
        }

        if (newCategoryId != null) {
          batch.update(productDoc.reference, {
            'category_id': newCategoryId,
            'category_path': categoryPath,
            'category_path_names': categoryPathNames,
            // Keep old fields for backward compatibility
            'category': categoryName,
            'subcategory': subcategoryName,
          });

          batchCount++;
          result.updatedProducts++;

          // Firestore batch limit is 500
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        } else {
          result.skippedProducts++;
        }
      }

      // Commit remaining batch
      if (batchCount > 0) {
        await batch.commit();
      }

      // Step 6: Mark old collections as deprecated (don't delete for safety)
      // We'll keep them for rollback purposes

      result.success = true;
      result.message = 'Migration completed successfully!';
    } catch (e) {
      result.success = false;
      result.message = 'Migration failed: $e';
      result.errors.add(e.toString());
    }

    return result;
  }

  /// Rollback migration (restore from old structure)
  Future<void> rollbackMigration() async {
    // Delete all new categories
    final newCategories = await _firestore
        .collection('categories')
        .where('level', isGreaterThanOrEqualTo: 0)
        .get();

    final batch = _firestore.batch();
    for (var doc in newCategories.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Restore products to use old category/subcategory fields
    // (They still have them due to backward compatibility)
  }

  /// Verification after migration
  Future<VerificationResult> verifyMigration() async {
    final result = VerificationResult();

    try {
      // Count new categories
      final rootCategories = await _firestore
          .collection('categories')
          .where('level', isEqualTo: 0)
          .get();
      result.rootCategoriesCount = rootCategories.docs.length;

      final level1Categories = await _firestore
          .collection('categories')
          .where('level', isEqualTo: 1)
          .get();
      result.level1CategoriesCount = level1Categories.docs.length;

      // Check products have category_id
      final productsWithCategory = await _firestore
          .collection('master_products')
          .where('category_id', isNull: false)
          .get();
      result.productsWithCategoryId = productsWithCategory.docs.length;

      final allProducts = await _firestore.collection('master_products').get();
      result.totalProducts = allProducts.docs.length;

      result.success = true;
    } catch (e) {
      result.success = false;
      result.message = e.toString();
    }

    return result;
  }
}

class MigrationResult {
  bool success = false;
  bool alreadyMigrated = false;
  String message = '';
  int oldCategoriesCount = 0;
  int oldSubcategoriesCount = 0;
  int migratedRootCategories = 0;
  int migratedSubcategories = 0;
  int skippedSubcategories = 0;
  int updatedProducts = 0;
  int skippedProducts = 0;
  List<String> errors = [];
}

class VerificationResult {
  bool success = false;
  String message = '';
  int rootCategoriesCount = 0;
  int level1CategoriesCount = 0;
  int productsWithCategoryId = 0;
  int totalProducts = 0;
}

/// UI Screen for Migration
class CategoryMigrationScreen extends StatefulWidget {
  const CategoryMigrationScreen({super.key});

  @override
  State<CategoryMigrationScreen> createState() => _CategoryMigrationScreenState();
}

class _CategoryMigrationScreenState extends State<CategoryMigrationScreen> {
  final _migrationScript = CategoryMigrationScript();
  final _levelFixer = CategoryLevelFixer();
  bool _isRunning = false;
  MigrationResult? _result;
  VerificationResult? _verification;
  LevelFixResult? _levelFixResult;
  CategoryLevelStats? _levelStats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Migration'),
        backgroundColor: const Color(0xFF0D9759),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important: Database Migration',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This will convert your 2-level category structure to unlimited hierarchy. '
                          'Please backup your database before proceeding.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Migration Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runMigration,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running Migration...' : 'Run Migration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Verify Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _verifyMigration,
              icon: const Icon(Icons.check_circle),
              label: const Text('Verify Migration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 32),

            // Level Fix Section
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Category Level Fix Utility',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this if categories are showing at wrong levels (e.g., showing level 1 instead of level 0)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Check Level Stats Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _checkLevelStats,
              icon: const Icon(Icons.analytics),
              label: const Text('Check Level Statistics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Fix Levels Button
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _fixCategoryLevels,
              icon: const Icon(Icons.build),
              label: const Text('Fix Category Levels'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

            const SizedBox(height: 24),

            // Results
            if (_result != null) _buildMigrationResult(),
            if (_verification != null) _buildVerificationResult(),
            if (_levelStats != null) _buildLevelStatsResult(),
            if (_levelFixResult != null) _buildLevelFixResult(),
          ],
        ),
      ),
    );
  }

  Future<void> _runMigration() async {
    setState(() => _isRunning = true);

    final result = await _migrationScript.runMigration(context);

    setState(() {
      _isRunning = false;
      _result = result;
    });

    if (result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Migration completed successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _verifyMigration() async {
    final verification = await _migrationScript.verifyMigration();
    setState(() => _verification = verification);
  }

  Widget _buildMigrationResult() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _result!.success ? Colors.green[50] : Colors.red[50],
        border: Border.all(color: _result!.success ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _result!.success ? Icons.check_circle : Icons.error,
                color: _result!.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Text(
                _result!.message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (!_result!.alreadyMigrated) ...[
            const SizedBox(height: 12),
            Text('Root Categories Migrated: ${_result!.migratedRootCategories}'),
            Text('Subcategories Migrated: ${_result!.migratedSubcategories}'),
            Text('Products Updated: ${_result!.updatedProducts}'),
            if (_result!.skippedSubcategories > 0)
              Text('Skipped Subcategories: ${_result!.skippedSubcategories}', style: const TextStyle(color: Colors.orange)),
            if (_result!.skippedProducts > 0)
              Text('Skipped Products: ${_result!.skippedProducts}', style: const TextStyle(color: Colors.orange)),
            if (_result!.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ..._result!.errors.map((e) => Text('• $e', style: const TextStyle(color: Colors.red))),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationResult() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 12),
              Text('Verification Results', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Root Categories: ${_verification!.rootCategoriesCount}'),
          Text('Level 1 Categories: ${_verification!.level1CategoriesCount}'),
          Text('Products with category_id: ${_verification!.productsWithCategoryId}'),
          Text('Total Products: ${_verification!.totalProducts}'),
        ],
      ),
    );
  }

  // New handler methods for level fix
  Future<void> _checkLevelStats() async {
    setState(() => _isRunning = true);
    final stats = await _levelFixer.getCategoryLevelStats();
    setState(() {
      _isRunning = false;
      _levelStats = stats;
    });
  }

  Future<void> _fixCategoryLevels() async {
    setState(() => _isRunning = true);
    final fixResult = await _levelFixer.fixAllCategoryLevels();
    setState(() {
      _isRunning = false;
      _levelFixResult = fixResult;
    });

    if (fixResult.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fixed ${fixResult.updatedCategories} categories!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh stats after fix
      _checkLevelStats();
    }
  }

  Widget _buildLevelStatsResult() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _levelStats!.hasIssues ? Colors.orange[50] : Colors.green[50],
        border: Border.all(
          color: _levelStats!.hasIssues ? Colors.orange : Colors.green,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _levelStats!.hasIssues ? Icons.warning : Icons.check_circle,
                color: _levelStats!.hasIssues ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 12),
              const Text(
                'Category Level Statistics',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Total Categories: ${_levelStats!.totalCategories}'),
          const SizedBox(height: 8),
          
          // Level breakdown
          const Text('Categories by Level:', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._levelStats!.levelCounts.entries.map((entry) => 
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('Level ${entry.key}: ${entry.value}'),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Issues
          if (_levelStats!.hasIssues) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Issues Found:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  if (_levelStats!.rootCategoriesWithWrongLevel > 0)
                    Text('⚠ ${_levelStats!.rootCategoriesWithWrongLevel} root categories have wrong level (should be 0)'),
                  if (_levelStats!.childrenWithWrongLevel > 0)
                    Text('⚠ ${_levelStats!.childrenWithWrongLevel} child categories marked as level 0'),
                  if (_levelStats!.categoriesWithoutLevel > 0)
                    Text('⚠ ${_levelStats!.categoriesWithoutLevel} categories missing level field'),
                  const SizedBox(height: 8),
                  const Text(
                    '👉 Click "Fix Category Levels" to resolve these issues',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '✓ All category levels are correct!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelFixResult() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _levelFixResult!.success ? Colors.green[50] : Colors.red[50],
        border: Border.all(
          color: _levelFixResult!.success ? Colors.green : Colors.red,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _levelFixResult!.success ? Icons.check_circle : Icons.error,
                color: _levelFixResult!.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _levelFixResult!.message,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_levelFixResult!.success) ...[
            const SizedBox(height: 12),
            Text('Total Categories: ${_levelFixResult!.totalCategories}'),
            Text('Updated Categories: ${_levelFixResult!.updatedCategories}'),
            if (_levelFixResult!.updatedCategories == 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '✓ All categories were already at correct levels',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
          if (_levelFixResult!.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ..._levelFixResult!.errors.map((e) => Text('• $e', style: const TextStyle(color: Colors.red))),
          ],
        ],
      ),
    );
  }
}
