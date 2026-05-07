import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onDelete,
    this.onEdit,
  });

  IconData _getCategoryIcon(String category) {
    final icons = {
      'Salary': Icons.work,
      'Freelance': Icons.computer,
      'Investment': Icons.trending_up,
      'Business': Icons.business,
      'Food': Icons.restaurant,
      'Transport': Icons.directions_car,
      'Shopping': Icons.shopping_bag,
      'Entertainment': Icons.movie,
      'Bills': Icons.receipt,
      'Healthcare': Icons.medical_services,
      'Education': Icons.school,
    };
    return icons[category] ?? Icons.category;
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: 'Tk ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isIncome = transaction.type == 'income';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(transaction.category),
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.category),
            Text(
              dateFormat.format(transaction.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Amount
            Text(
              currencyFormat.format(transaction.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 4),
            // Edit button — সবসময় দেখাবে
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 4),
            // Delete button — সবসময় দেখাবে
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _confirmDelete(context),
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}