import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final String period; // 'monthly' or 'yearly'
  final DateTime createdAt;

  Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.period,
    required this.createdAt,
  });

  // Firestore থেকে read
  factory Budget.fromFirestore(Map<String, dynamic> data) {
    return Budget(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      category: data['category'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      period: data['period'] ?? 'monthly',
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // পুরোনো JSON format
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      category: json['category'],
      amount: json['amount'].toDouble(),
      period: json['period'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Firestore এ save করার জন্য
  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'amount': amount,
      'period': period,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'period': period,
    };
  }
}

// Budget Status - spending vs budget
class BudgetStatus {
  final Budget budget;
  final double spent;
  final double remaining;
  final double percentage;
  final bool isExceeded;
  final bool isWarning; // 80% reached

  BudgetStatus({
    required this.budget,
    required this.spent,
  })  : remaining = budget.amount - spent,
        percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0,
        isExceeded = spent > budget.amount,
        isWarning = budget.amount > 0 && (spent / budget.amount) >= 0.8;
}
