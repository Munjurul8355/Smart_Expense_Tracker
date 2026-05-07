import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart' as app_model;

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  TransactionService(this.userId);

  CollectionReference get _transactions =>
      _db.collection('users').doc(userId).collection('transactions');

  Future<List<app_model.Transaction>> getTransactions({String? type}) async {
    try {
      // শুধু date দিয়ে sort করো — type filter Dart এ করো
      final snapshot = await _transactions
          .orderBy('date', descending: true)
          .get();

      final allTransactions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return app_model.Transaction.fromFirestore(data);
      }).toList();

      // type filter Dart এ করো (Firestore index লাগবে না)
      if (type != null) {
        return allTransactions.where((t) => t.type == type).toList();
      }

      return allTransactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Stream<List<app_model.Transaction>> transactionsStream({String? type}) {
    return _transactions
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      final all = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return app_model.Transaction.fromFirestore(data);
      }).toList();

      if (type != null) {
        return all.where((t) => t.type == type).toList();
      }
      return all;
    });
  }

  Future<app_model.Transaction?> addTransaction(
      app_model.Transaction transaction) async {
    try {
      final docRef = await _transactions.add(transaction.toFirestore());
      final doc = await docRef.get();
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return app_model.Transaction.fromFirestore(data);
    } catch (e) {
      print('Error adding transaction: $e');
      return null;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _transactions.doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting transaction: $e');
      return false;
    }
  }

  Future<bool> updateTransaction(
      String id, app_model.Transaction transaction) async {
    try {
      await _transactions.doc(id).update(transaction.toFirestore());
      return true;
    } catch (e) {
      print('Error updating transaction: $e');
      return false;
    }
  }

  Future<Map<String, double>> getSummary() async {
    try {
      final snapshot = await _transactions.get();
      double totalIncome = 0;
      double totalExpense = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final type = data['type'] ?? 'expense';
        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }
      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
      };
    } catch (e) {
      print('Error fetching summary: $e');
      return {'totalIncome': 0, 'totalExpense': 0, 'balance': 0};
    }
  }

  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
      final snapshot = await _transactions
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      double totalIncome = 0;
      double totalExpense = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final type = data['type'] ?? 'expense';
        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }
      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
      };
    } catch (e) {
      print('Error fetching monthly summary: $e');
      return {'totalIncome': 0, 'totalExpense': 0, 'balance': 0};
    }
  }
}