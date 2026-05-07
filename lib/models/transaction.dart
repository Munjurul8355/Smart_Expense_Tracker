import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String type; // 'income' or 'expense'
  final String? description;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.type,
    this.description,
  });

  // Firestore থেকে read করার জন্য
  factory Transaction.fromFirestore(Map<String, dynamic> data) {
    return Transaction(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      type: data['type'] ?? 'expense',
      description: data['description'],
    );
  }

  // পুরোনো JSON format (backward compatible)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? 'expense',
      description: json['description'],
    );
  }

  // Firestore এ save করার জন্য
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'type': type,
      'description': description,
    };
  }

  // পুরোনো JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'type': type,
      'description': description,
    };
  }
}
