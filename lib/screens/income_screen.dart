import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../models/transaction.dart';
import '../utils/excel_export.dart';
import '../widgets/transaction_card.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  List<Transaction> incomes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIncomes();
  }

  Future<void> _loadIncomes() async {
    setState(() => isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final transactionService = TransactionService(authService.currentUserId!);
    final data = await transactionService.getTransactions(type: 'income');
    if (mounted) {
      setState(() {
        incomes = data;
        isLoading = false;
      });
    }
  }

  Future<void> _deleteIncome(String id) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final transactionService = TransactionService(authService.currentUserId!);
    final success = await transactionService.deleteTransaction(id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Income deleted successfully')),
      );
      _loadIncomes();
    }
  }

  Future<void> _exportToExcel() async {
    await ExcelExport.exportTransactions(incomes, 'income');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Income exported to Excel')),
      );
    }
  }

  void _showAddIncomeDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Salary';
    bool isSaving = false;
    final categories = ['Salary', 'Freelance', 'Investment', 'Business', 'Other'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Income'),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: isSaving ? null : (value) {
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
              onPressed: isSaving ? null : () async {
                if (titleController.text.trim().isEmpty) return;
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;

                setDialogState(() => isSaving = true);
                try {
                  final transaction = Transaction(
                    id: '',
                    title: titleController.text.trim(),
                    amount: amount,
                    category: selectedCategory,
                    date: DateTime.now(),
                    type: 'income',
                  );
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final result = await TransactionService(authService.currentUserId!).addTransaction(transaction);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result != null ? 'Income added successfully' : 'Error! আবার try করো'),
                      backgroundColor: result != null ? null : Colors.red,
                    ));
                    if (result != null) _loadIncomes();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditIncomeDialog(Transaction income) {
    final titleController = TextEditingController(text: income.title);
    final amountController = TextEditingController(text: income.amount.toString());
    String selectedCategory = income.category;
    bool isSaving = false;
    final categories = ['Salary', 'Freelance', 'Investment', 'Business', 'Other'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Income'),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: isSaving ? null : (value) {
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
              onPressed: isSaving ? null : () async {
                if (titleController.text.trim().isEmpty) return;
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;

                setDialogState(() => isSaving = true);
                try {
                  final updated = Transaction(
                    id: income.id,
                    title: titleController.text.trim(),
                    amount: amount,
                    category: selectedCategory,
                    date: income.date,
                    type: 'income',
                  );
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final success = await TransactionService(authService.currentUserId!).updateTransaction(income.id, updated);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success ? 'Income updated successfully' : 'Error! আবার try করো'),
                      backgroundColor: success ? null : Colors.red,
                    ));
                    if (success) _loadIncomes();
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        title: const Text('Income'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: incomes.isEmpty ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : incomes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No income records yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadIncomes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: incomes.length,
                    itemBuilder: (context, index) {
                      return TransactionCard(
                        transaction: incomes[index],
                        onDelete: () => _deleteIncome(incomes[index].id),
                        onEdit: () => _showEditIncomeDialog(incomes[index]),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIncomeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}