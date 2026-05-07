import 'package:cloud_firestore/cloud_firestore.dart';

class CustomCategory {
  final String id;
  final String userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String? icon;
  final String? color;
  final DateTime createdAt;

  CustomCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.createdAt,
  });

  // Firestore থেকে read
  factory CustomCategory.fromFirestore(Map<String, dynamic> data) {
    return CustomCategory(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'expense',
      icon: data['icon'],
      color: data['color'],
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // পুরোনো JSON format
  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      name: json['name'],
      type: json['type'],
      icon: json['icon'],
      color: json['color'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Firestore এ save করার জন্য
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
    };
  }
}

// Default categories
class CategoryHelper {
  static List<String> getDefaultIncomeCategories() {
    return ['Salary', 'Freelance', 'Investment', 'Business', 'Other'];
  }

  static List<String> getDefaultExpenseCategories() {
    return [
      'Food',
      'Transport',
      'Shopping',
      'Entertainment',
      'Bills',
      'Healthcare',
      'Education',
      'Other'
    ];
  }

  static List<String> getAllCategories(
    String type,
    List<CustomCategory> customCategories,
  ) {
    List<String> defaults = type == 'income'
        ? getDefaultIncomeCategories()
        : getDefaultExpenseCategories();

    List<String> customs = customCategories
        .where((c) => c.type == type)
        .map((c) => c.name)
        .toList();

    return [...defaults, ...customs];
  }
}
