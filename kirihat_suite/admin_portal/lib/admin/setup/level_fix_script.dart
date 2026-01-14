import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility to fix category level inconsistencies
/// This recalculates all category levels based on their parent_id relationships
class CategoryLevelFixer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fix all category levels in the database
  Future<LevelFixResult> fixAllCategoryLevels() async {
    final result = LevelFixResult();

    try {
      // Step 1: Get all categories
      final allCategories = await _firestore.collection('categories').get();
      result.totalCategories = allCategories.docs.length;

      if (allCategories.docs.isEmpty) {
        result.message = 'No categories found';
        result.success = true;
        return result;
      }

      // Step 2: Find and fix root categories (parent_id == null)
      final rootCategories = allCategories.docs.where((doc) {
        final data = doc.data();
        return data['parent_id'] == null;
      }).toList();

      result.message = 'Fixing root categories...';
      
      for (var doc in rootCategories) {
        final data = doc.data();
        final currentLevel = data['level'] ?? -1;

        if (currentLevel != 0) {
          await _firestore.collection('categories').doc(doc.id).update({
            'level': 0,
            'path': <String>[],
            'path_names': <String>[],
            'updated_at': FieldValue.serverTimestamp(),
          });
          result.updatedCategories++;
        }
      }

      // Step 3: Recursively fix all child categories
      result.message = 'Fixing child categories...';
      
      for (var rootDoc in rootCategories) {
        await _fixChildrenLevels(
          rootDoc.id,
          rootDoc.data()['name'] ?? 'Unnamed',
          0,
          [],
          [],
          result,
        );
      }

      result.success = true;
      result.message = 'Category levels fixed successfully!';
    } catch (e) {
      result.success = false;
      result.message = 'Error fixing levels: $e';
      result.errors.add(e.toString());
    }

    return result;
  }

  /// Recursively fix children of a category
  Future<void> _fixChildrenLevels(
    String parentId,
    String parentName,
    int parentLevel,
    List<String> parentPath,
    List<String> parentPathNames,
    LevelFixResult result,
  ) async {
    // Get all children of this parent
    final children = await _firestore
        .collection('categories')
        .where('parent_id', isEqualTo: parentId)
        .get();

    final correctLevel = parentLevel + 1;
    final correctPath = [...parentPath, parentId];
    final correctPathNames = [...parentPathNames, parentName];

    for (var childDoc in children.docs) {
      final childData = childDoc.data();
      final currentLevel = childData['level'] ?? -1;
      final currentPath = childData['path'] != null 
          ? List<String>.from(childData['path']) 
          : <String>[];
      final currentPathNames = childData['path_names'] != null
          ? List<String>.from(childData['path_names'])
          : <String>[];

      // Check if we need to update
      final needsUpdate = currentLevel != correctLevel ||
          !_listEquals(currentPath, correctPath) ||
          !_listEquals(currentPathNames, correctPathNames);

      if (needsUpdate) {
        await _firestore.collection('categories').doc(childDoc.id).update({
          'level': correctLevel,
          'path': correctPath,
          'path_names': correctPathNames,
          'updated_at': FieldValue.serverTimestamp(),
        });
        result.updatedCategories++;
      }

      // Recursively fix this child's children
      await _fixChildrenLevels(
        childDoc.id,
        childData['name'] ?? 'Unnamed',
        correctLevel,
        correctPath,
        correctPathNames,
        result,
      );
    }
  }

  /// Helper to compare two lists
  bool _listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Get statistics about current category levels
  Future<CategoryLevelStats> getCategoryLevelStats() async {
    final stats = CategoryLevelStats();

    try {
      final allCategories = await _firestore.collection('categories').get();
      stats.totalCategories = allCategories.docs.length;

      // Count categories by level
      final Map<int, int> levelCounts = {};
      int categoriesWithoutLevel = 0;
      int rootCategoriesWithWrongLevel = 0;
      int childrenWithWrongLevel = 0;

      for (var doc in allCategories.docs) {
        final data = doc.data();
        final level = data['level'];
        final parentId = data['parent_id'];

        if (level == null) {
          categoriesWithoutLevel++;
        } else {
          levelCounts[level] = (levelCounts[level] ?? 0) + 1;

          // Check if level is correct based on parent_id
          if (parentId == null && level != 0) {
            rootCategoriesWithWrongLevel++;
          } else if (parentId != null && level == 0) {
            childrenWithWrongLevel++;
          }
        }
      }

      stats.categoriesWithoutLevel = categoriesWithoutLevel;
      stats.rootCategoriesWithWrongLevel = rootCategoriesWithWrongLevel;
      stats.childrenWithWrongLevel = childrenWithWrongLevel;
      stats.levelCounts = levelCounts;
      stats.success = true;
    } catch (e) {
      stats.success = false;
      stats.message = 'Error getting stats: $e';
    }

    return stats;
  }
}

class LevelFixResult {
  bool success = false;
  String message = '';
  int totalCategories = 0;
  int updatedCategories = 0;
  List<String> errors = [];
}

class CategoryLevelStats {
  bool success = false;
  String message = '';
  int totalCategories = 0;
  int categoriesWithoutLevel = 0;
  int rootCategoriesWithWrongLevel = 0;
  int childrenWithWrongLevel = 0;
  Map<int, int> levelCounts = {};

  bool get hasIssues => 
      categoriesWithoutLevel > 0 || 
      rootCategoriesWithWrongLevel > 0 || 
      childrenWithWrongLevel > 0;
}
