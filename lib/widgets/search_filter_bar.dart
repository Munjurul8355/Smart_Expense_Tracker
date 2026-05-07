import 'package:flutter/material.dart';
import '../models/transaction.dart';

class SearchFilterBar extends StatefulWidget {
  final List<Transaction> allTransactions;
  final Function(List<Transaction>) onFilterChanged;

  const SearchFilterBar({
    Key? key,
    required this.allTransactions,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  DateTimeRange? _dateRange;
  double? _minAmount;
  double? _maxAmount;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    List<Transaction> filtered = widget.allTransactions;

    // Search by title
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.title
            .toLowerCase()
            .contains(_searchController.text.toLowerCase());
      }).toList();
    }

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered =
          filtered.where((t) => t.category == _selectedCategory).toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      filtered = filtered.where((t) {
        return t.date.isAfter(_dateRange!.start.subtract(Duration(days: 1))) &&
            t.date.isBefore(_dateRange!.end.add(Duration(days: 1)));
      }).toList();
    }

    // Filter by amount range
    if (_minAmount != null) {
      filtered = filtered.where((t) => t.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _maxAmount!).toList();
    }

    widget.onFilterChanged(filtered);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedCategory: _selectedCategory,
        dateRange: _dateRange,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
        onApply: (category, dateRange, minAmt, maxAmt) {
          setState(() {
            _selectedCategory = category;
            _dateRange = dateRange;
            _minAmount = minAmt;
            _maxAmount = maxAmt;
          });
          _applyFilters();
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = null;
      _dateRange = null;
      _minAmount = null;
      _maxAmount = null;
    });
    _applyFilters();
  }

  bool get _hasActiveFilters {
    return _searchController.text.isNotEmpty ||
        _selectedCategory != null ||
        _dateRange != null ||
        _minAmount != null ||
        _maxAmount != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
              SizedBox(width: 12),
              IconButton(
                onPressed: _showFilterDialog,
                icon: Stack(
                  children: [
                    Icon(Icons.filter_list, size: 28),
                    if (_hasActiveFilters)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Filter',
              ),
              if (_hasActiveFilters)
                IconButton(
                  onPressed: _clearFilters,
                  icon: Icon(Icons.clear_all),
                  tooltip: 'Clear filters',
                ),
            ],
          ),
        ),
        // Active filters chips
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              children: [
                if (_selectedCategory != null)
                  Chip(
                    label: Text('Category: $_selectedCategory'),
                    onDeleted: () {
                      setState(() => _selectedCategory = null);
                      _applyFilters();
                    },
                  ),
                if (_dateRange != null)
                  Chip(
                    label: Text('Date range'),
                    onDeleted: () {
                      setState(() => _dateRange = null);
                      _applyFilters();
                    },
                  ),
                if (_minAmount != null || _maxAmount != null)
                  Chip(
                    label: Text(
                      'Amount: ${_minAmount ?? 0} - ${_maxAmount ?? '∞'}',
                    ),
                    onDeleted: () {
                      setState(() {
                        _minAmount = null;
                        _maxAmount = null;
                      });
                      _applyFilters();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// Filter Dialog
class _FilterDialog extends StatefulWidget {
  final String? selectedCategory;
  final DateTimeRange? dateRange;
  final double? minAmount;
  final double? maxAmount;
  final Function(String?, DateTimeRange?, double?, double?) onApply;

  const _FilterDialog({
    required this.selectedCategory,
    required this.dateRange,
    required this.minAmount,
    required this.maxAmount,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  String? _category;
  DateTimeRange? _dateRange;
  TextEditingController _minController = TextEditingController();
  TextEditingController _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _dateRange = widget.dateRange;
    if (widget.minAmount != null) {
      _minController.text = widget.minAmount.toString();
    }
    if (widget.maxAmount != null) {
      _maxController.text = widget.maxAmount.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Food',
      'Transport',
      'Shopping',
      'Entertainment',
      'Bills',
      'Healthcare',
      'Education',
      'Other',
      'Salary',
      'Freelance',
      'Investment',
      'Business',
    ];

    return AlertDialog(
      title: Text('Filter Transactions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter
            Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select category',
              ),
              items: [
                DropdownMenuItem(value: null, child: Text('All')),
                ...categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            SizedBox(height: 16),

            // Date Range Filter
            Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() => _dateRange = picked);
                }
              },
              icon: Icon(Icons.calendar_today),
              label: Text(_dateRange == null
                  ? 'Select date range'
                  : '${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}'),
            ),
            if (_dateRange != null)
              TextButton(
                onPressed: () => setState(() => _dateRange = null),
                child: Text('Clear'),
              ),
            SizedBox(height: 16),

            // Amount Range Filter
            Text('Amount Range', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    decoration: InputDecoration(
                      labelText: 'Min',
                      border: OutlineInputBorder(),
                      prefixText: 'Tk ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    decoration: InputDecoration(
                      labelText: 'Max',
                      border: OutlineInputBorder(),
                      prefixText: 'Tk ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            double? min = _minController.text.isEmpty
                ? null
                : double.tryParse(_minController.text);
            double? max = _maxController.text.isEmpty
                ? null
                : double.tryParse(_maxController.text);

            widget.onApply(_category, _dateRange, min, max);
            Navigator.pop(context);
          },
          child: Text('Apply'),
        ),
      ],
    );
  }
}
