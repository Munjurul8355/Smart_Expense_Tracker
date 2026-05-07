import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  CategoryService(this.userId);

  CollectionReference get _categories =>
      _db.collection('users').doc(userId).collection('categories');

  // Custom categories get করো
  Future<List<CustomCategory>> getCustomCategories() async {
    try {
      final snapshot =
          await _categories.orderBy('created_at', descending: false).get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return CustomCategory.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  // Custom category create করো
  Future<bool> createCategory(CustomCategory category) async {
    try {
      await _categories.add(category.toFirestore());
      return true;
    } catch (e) {
      print('Error creating category: $e');
      return false;
    }
  }

  // Category update করো
  Future<bool> updateCategory(String id, CustomCategory category) async {
    try {
      await _categories.doc(id).update(category.toFirestore());
      return true;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  // Category delete করো
  Future<bool> deleteCategory(String id) async {
    try {
      await _categories.doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }
}
