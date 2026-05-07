import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  BudgetService(this.userId);

  CollectionReference get _budgets =>
      _db.collection('users').doc(userId).collection('budgets');

  // সব budgets get করো
  Future<List<Budget>> getBudgets() async {
    try {
      final snapshot = await _budgets.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Budget.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Error fetching budgets: $e');
      return [];
    }
  }

  // Budget status calculate করো (Firestore থেকে transactions দেখে)
  Future<Map<String, BudgetStatus>> getBudgetStatus() async {
    try {
      final budgets = await getBudgets();
      if (budgets.isEmpty) return {};

      // এই মাসের transactions get করো
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final txSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      // Category অনুযায়ী spending calculate করো
      Map<String, double> spentByCategory = {};
      for (var doc in txSnapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? '';
        final amount = (data['amount'] ?? 0).toDouble();
        spentByCategory[category] = (spentByCategory[category] ?? 0) + amount;
      }

      Map<String, BudgetStatus> statusMap = {};
      for (var budget in budgets) {
        final spent = spentByCategory[budget.category] ?? 0;
        statusMap[budget.category] = BudgetStatus(
          budget: budget,
          spent: spent,
        );
      }

      return statusMap;
    } catch (e) {
      print('Error fetching budget status: $e');
      return {};
    }
  }

  // Budget create করো
  Future<bool> createBudget(Budget budget) async {
    try {
      await _budgets.add(budget.toFirestore());
      return true;
    } catch (e) {
      print('Error creating budget: $e');
      return false;
    }
  }

  // Budget update করো
  Future<bool> updateBudget(String id, Budget budget) async {
    try {
      await _budgets.doc(id).update(budget.toFirestore());
      return true;
    } catch (e) {
      print('Error updating budget: $e');
      return false;
    }
  }

  // Budget delete করো
  Future<bool> deleteBudget(String id) async {
    try {
      await _budgets.doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting budget: $e');
      return false;
    }
  }
}
