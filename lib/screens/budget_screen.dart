import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget.dart';
import '../services/auth_service.dart';
import '../services/budget_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Budget> _budgets = [];
  Map<String, BudgetStatus> _budgetStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId!;
    final budgetService = BudgetService(userId);

    final budgets = await budgetService.getBudgets();
    final status = await budgetService.getBudgetStatus();

    setState(() {
      _budgets = budgets;
      _budgetStatus = status;
      _isLoading = false;
    });
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddBudgetDialog(onSave: () => _loadBudgets()),
    );
  }

  void _showEditBudgetDialog(Budget budget) {
    showDialog(
      context: context,
      builder: (context) => _AddBudgetDialog(budget: budget, onSave: () => _loadBudgets()),
    );
  }

  Future<void> _deleteBudget(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Budget'),
        content: Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final budgetService = BudgetService(userId);

      final success = await budgetService.deleteBudget(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget deleted successfully')),
        );
        _loadBudgets();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Budget Management'),
        actions: [
          IconButton(
              onPressed: _loadBudgets,
              icon: Icon(Icons.refresh),
              tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBudgets,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final budget = _budgets[index];
                      final status = _budgetStatus[budget.category];
                      return _buildBudgetCard(budget, status);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: Icon(Icons.add),
        tooltip: 'Add Budget',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 100, color: Colors.grey),
          SizedBox(height: 16),
          Text('No budgets yet',
              style: TextStyle(fontSize: 20, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Tap + to create your first budget',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget, BudgetStatus? status) {
    final spent = status?.spent ?? 0;
    final remaining = status?.remaining ?? budget.amount;
    final percentage = status?.percentage ?? 0;

    Color progressColor = Colors.green;
    if (percentage >= 100) {
      progressColor = Colors.red;
    } else if (percentage >= 80) {
      progressColor = Colors.orange;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(budget.category,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit')
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red))
                      ]),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditBudgetDialog(budget);
                    } else if (value == 'delete') {
                      _deleteBudget(budget.id);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('${budget.period.toUpperCase()} Budget',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent', style: TextStyle(fontSize: 12)),
                    Text('Tk ${spent.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Budget', style: TextStyle(fontSize: 12)),
                    Text('Tk ${budget.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage > 100 ? 1.0 : percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${percentage.toStringAsFixed(1)}% used',
                    style: TextStyle(fontSize: 12, color: progressColor)),
                Text('Remaining: Tk ${remaining.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
            if (percentage >= 100)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Budget exceeded!',
                          style: TextStyle(color: Colors.red))),
                ]),
              ),
            if (percentage >= 80 && percentage < 100)
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Approaching budget limit',
                          style: TextStyle(color: Colors.orange))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddBudgetDialog extends StatefulWidget {
  final Budget? budget;
  final VoidCallback onSave;

  const _AddBudgetDialog({this.budget, required this.onSave});

  @override
  State<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<_AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  String _period = 'monthly';
  final _amountController = TextEditingController();

  final categories = [
    'Food', 'Transport', 'Shopping', 'Entertainment',
    'Bills', 'Healthcare', 'Education', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _category = widget.budget!.category;
      _period = widget.budget!.period;
      _amountController.text = widget.budget!.amount.toString();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId!;
    final budgetService = BudgetService(userId);

    final budget = Budget(
      id: widget.budget?.id ?? '',
      userId: userId,
      category: _category!,
      amount: double.parse(_amountController.text),
      period: _period,
      createdAt: DateTime.now(),
    );

    bool success;
    if (widget.budget == null) {
      success = await budgetService.createBudget(budget);
    } else {
      success = await budgetService.updateBudget(widget.budget!.id, budget);
    }

    if (success) {
      Navigator.pop(context);
      widget.onSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.budget == null
              ? 'Budget created successfully'
              : 'Budget updated successfully'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save budget')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.budget == null ? 'Add Budget' : 'Edit Budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              validator: (value) =>
                  value == null ? 'Please select category' : null,
              onChanged: (value) => setState(() => _category = value),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                  labelText: 'Budget Amount',
                  border: OutlineInputBorder(),
                  prefixText: 'Tk '),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter amount';
                if (double.tryParse(value) == null) return 'Please enter valid amount';
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _period,
              decoration: InputDecoration(
                  labelText: 'Period', border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              ],
              onChanged: (value) => setState(() => _period = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(onPressed: _save, child: Text('Save')),
      ],
    );
  }
}
