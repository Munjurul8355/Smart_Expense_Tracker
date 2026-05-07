import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../models/transaction.dart';
import '../utils/excel_export.dart';
import '../widgets/transaction_card.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Transaction> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final transactionService = TransactionService(authService.currentUserId!);
    final data = await transactionService.getTransactions(type: 'expense');
    if (mounted) {
      setState(() {
        expenses = data;
        isLoading = false;
      });
    }
  }

  Future<void> _deleteExpense(String id) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final transactionService = TransactionService(authService.currentUserId!);
    final success = await transactionService.deleteTransaction(id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );
      _loadExpenses();
    }
  }

  Future<void> _exportToExcel() async {
    await ExcelExport.exportTransactions(expenses, 'expense');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expenses exported to Excel')),
      );
    }
  }

  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Food';
    bool isSaving = false;
    final categories = [
      'Food', 'Transport', 'Shopping', 'Entertainment',
      'Bills', 'Healthcare', 'Education', 'Other'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: 'Tk '),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                        value: category, child: Text(category));
                  }).toList(),
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setDialogState(() => selectedCategory = value!);
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      // Validation
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Title দাও')),
                        );
                        return;
                      }
                      if (amountController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Amount দাও')),
                        );
                        return;
                      }
                      final amount =
                          double.tryParse(amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('সঠিক amount দাও')),
                        );
                        return;
                      }

                      // Loading শুরু
                      setDialogState(() => isSaving = true);

                      try {
                        final transaction = Transaction(
                          id: '',
                          title: titleController.text.trim(),
                          amount: amount,
                          category: selectedCategory,
                          date: DateTime.now(),
                          type: 'expense',
                        );

                        final authService = Provider.of<AuthService>(
                            context,
                            listen: false);
                        final transactionService =
                            TransactionService(authService.currentUserId!);

                        final result = await transactionService
                            .addTransaction(transaction);

                        if (mounted) {
                          Navigator.pop(context);
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Expense added successfully')),
                            );
                            _loadExpenses();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Error! আবার try করো'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseDialog(Transaction expense) {
    final titleController = TextEditingController(text: expense.title);
    final amountController =
        TextEditingController(text: expense.amount.toString());
    String selectedCategory = expense.category;
    bool isSaving = false;
    final categories = [
      'Food', 'Transport', 'Shopping', 'Entertainment',
      'Bills', 'Healthcare', 'Education', 'Other'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: 'Tk '),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                        value: category, child: Text(category));
                  }).toList(),
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setDialogState(() => selectedCategory = value!);
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          amountController.text.trim().isEmpty) return;

                      final amount =
                          double.tryParse(amountController.text.trim());
                      if (amount == null || amount <= 0) return;

                      setDialogState(() => isSaving = true);

                      try {
                        final updatedTransaction = Transaction(
                          id: expense.id,
                          title: titleController.text.trim(),
                          amount: amount,
                          category: selectedCategory,
                          date: expense.date,
                          type: 'expense',
                        );

                        final authService = Provider.of<AuthService>(
                            context,
                            listen: false);
                        final transactionService =
                            TransactionService(authService.currentUserId!);

                        final success =
                            await transactionService.updateTransaction(
                                expense.id, updatedTransaction);

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Expense updated successfully'
                                  : 'Error! আবার try করো'),
                              backgroundColor:
                                  success ? null : Colors.red,
                            ),
                          );
                          if (success) _loadExpenses();
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: expenses.isEmpty ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No expense records yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExpenses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      return TransactionCard(
                        transaction: expenses[index],
                        onDelete: () => _deleteExpense(expenses[index].id),
                        onEdit: () => _showEditExpenseDialog(expenses[index]),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}