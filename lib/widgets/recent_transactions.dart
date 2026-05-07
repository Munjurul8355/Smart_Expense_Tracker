import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class RecentTransactions extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onRefresh;

  const RecentTransactions({
    super.key,
    required this.transactions,
    required this.onRefresh,
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

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No recent transactions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: 'Tk ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd');

    return Card(
      elevation: 2,
      child: Column(
        children: transactions.map((transaction) {
          final isIncome = transaction.type == 'income';
          
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: isIncome ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              transaction.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${transaction.category} • ${dateFormat.format(transaction.date)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Text(
              '${isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}