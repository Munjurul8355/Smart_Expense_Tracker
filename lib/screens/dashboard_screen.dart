import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../services/pdf_service.dart';
import '../services/budget_service.dart';
import 'pdf_download_dialog.dart';
import '../widgets/summary_card.dart';
import '../widgets/chart_widget.dart';
import '../widgets/recent_transactions.dart';
import 'income_screen.dart';
import 'expense_screen.dart';
import 'settings_screen.dart';
import 'budget_screen.dart';
import 'budget_notification_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String _selectedPeriod = 'This Month';

  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;

  String? _userName;
  String? _userEmail;

  List<BudgetAlert> _budgetAlerts = [];

  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;
  late Animation<double> _fabExpandAnim;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabScaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
    _fabExpandAnim = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeInOut,
    );
    _loadUserInfo();
    _loadData();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() {
      _userName = authService.userName ?? 'User';
      _userEmail = authService.userEmail ?? '';
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId!;
    final transactionService = TransactionService(userId);
    final transactions = await transactionService.getTransactions();

    if (transactions.isNotEmpty) {
      final oldest = transactions
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      await authService.setAccountCreatedAtFromTransactions(oldest);
    }

    setState(() {
      _transactions = transactions;
      _filterTransactionsByPeriod();
      _isLoading = false;
    });

    if (mounted) {
      await _checkBudgetAlerts();
    }
  }

  // ─── Month-based dismiss key ──────────────────────────────────────────────
  String _globalDismissedKey() {
    final now = DateTime.now();
    final monthTag = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return 'budget_dialog_dismissed_$monthTag';
  }

  // ─── Main budget alert checker ────────────────────────────────────────────
  Future<void> _checkBudgetAlerts() async {
    try {
      // ✅ Check if already dismissed this month
      final prefs = await SharedPreferences.getInstance();
      final dismissedKey = _globalDismissedKey();

      if (prefs.getBool(dismissedKey) == true) {
        // Popup dismissed this month → just load alerts for banner/icon
        await _loadBudgetAlertsOnly();
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final budgetService = BudgetService(userId);
      final budgets = await budgetService.getBudgets();

      // ✅ Only current month transactions
      final now = DateTime.now();
      final currentMonthTransactions = _transactions.where((t) {
        return t.date.year == now.year && t.date.month == now.month;
      }).toList();

      final List<BudgetAlert> alerts = [];

      for (final budget in budgets) {
        final spent = currentMonthTransactions
            .where((t) =>
                t.type == 'expense' &&
                t.category.toLowerCase() == budget.category.toLowerCase())
            .fold(0.0, (sum, t) => sum + t.amount);

        final percentage =
            budget.amount > 0 ? (spent / budget.amount) * 100 : 0.0;

        if (percentage >= 80) {
          alerts.add(BudgetAlert(
            category: budget.category,
            budgetAmount: budget.amount,
            spentAmount: spent,
            percentage: percentage,
            type: percentage >= 100
                ? BudgetAlertType.exceeded
                : BudgetAlertType.warning,
          ));
        }
      }

      if (mounted) {
        setState(() => _budgetAlerts = alerts);

        if (alerts.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            // ✅ await so we know when user dismissed
            await showDialog(
              context: context,
              barrierDismissible: false, // must tap Got it or X
              builder: (_) => BudgetAlertDialog(alerts: alerts),
            );
            // ✅ Save dismissed state after dialog closes
            await prefs.setBool(dismissedKey, true);
          }
        }
      }
    } catch (e) {
      debugPrint('Budget alert check failed: $e');
    }
  }

  // ─── Loads alerts for banner/icon only (no popup) ─────────────────────────
  Future<void> _loadBudgetAlertsOnly() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final budgetService = BudgetService(userId);
      final budgets = await budgetService.getBudgets();

      final now = DateTime.now();
      final currentMonthTransactions = _transactions.where((t) {
        return t.date.year == now.year && t.date.month == now.month;
      }).toList();

      final List<BudgetAlert> alerts = [];

      for (final budget in budgets) {
        final spent = currentMonthTransactions
            .where((t) =>
                t.type == 'expense' &&
                t.category.toLowerCase() == budget.category.toLowerCase())
            .fold(0.0, (sum, t) => sum + t.amount);

        final percentage =
            budget.amount > 0 ? (spent / budget.amount) * 100 : 0.0;

        if (percentage >= 80) {
          alerts.add(BudgetAlert(
            category: budget.category,
            budgetAmount: budget.amount,
            spentAmount: spent,
            percentage: percentage,
            type: percentage >= 100
                ? BudgetAlertType.exceeded
                : BudgetAlertType.warning,
          ));
        }
      }

      if (mounted) {
        setState(() => _budgetAlerts = alerts);
      }
    } catch (e) {
      debugPrint('Budget alert load failed: $e');
    }
  }

  void _filterTransactionsByPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Month':
        final startDate = DateTime(now.year, now.month, 1);
        _filteredTransactions = _transactions.where((t) {
          return t.date.isAfter(startDate.subtract(const Duration(days: 1)));
        }).toList();
        break;
      case 'This Year':
        final startDate = DateTime(now.year, 1, 1);
        _filteredTransactions = _transactions.where((t) {
          return t.date.isAfter(startDate.subtract(const Duration(days: 1)));
        }).toList();
        break;
      default:
        _filteredTransactions = List.from(_transactions);
        break;
    }
    _calculateTotals();
  }

  void _calculateTotals() {
    _totalIncome = _filteredTransactions
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);
    _totalExpense = _filteredTransactions
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);
    _balance = _totalIncome - _totalExpense;
  }

  DateTime _getAllTimeStartDate() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (_transactions.isNotEmpty) {
      return _transactions
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    }
    return authService.accountCreatedAt ?? DateTime.now();
  }

  Future<void> _generatePDFReport() async {
    try {
      final now = DateTime.now();
      DateTime startDate;

      if (_selectedPeriod == 'This Month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (_selectedPeriod == 'This Year') {
        startDate = DateTime(now.year, 1, 1);
      } else {
        startDate = _getAllTimeStartDate();
      }

      final pdf = await PDFService.generateReport(
        transactions: _filteredTransactions,
        startDate: startDate,
        endDate: now,
        reportType: _selectedPeriod,
      );

      await PDFService.savePDF(
        pdf,
        'expense_report_${DateFormat('yyyy-MM-dd').format(now)}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(context, SlidePageRoute(page: screen));
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[800]!, Colors.blue[500]!],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 34,
                            backgroundColor: Color(0x40FFFFFF),
                            child: Icon(Icons.person,
                                size: 36, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome back,',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400)),
                              const SizedBox(height: 2),
                              Consumer<AuthService>(
                                builder: (context, auth, _) => Text(
                                  auth.userName ?? _userName ?? 'Loading...',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PulseDot(),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              if (_budgetAlerts.isNotEmpty)
                _AnimatedIconButton(
                  icon: Icons.notifications_active,
                  tooltip: 'Budget Alerts',
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) =>
                        BudgetAlertDialog(alerts: _budgetAlerts),
                  ),
                  hasBadge: true,
                  badgeCount: _budgetAlerts.length,
                  badgeColor: _budgetAlerts
                          .any((a) => a.type == BudgetAlertType.exceeded)
                      ? Colors.red
                      : Colors.orange,
                ),
              _AnimatedIconButton(
                icon: Icons.picture_as_pdf,
                tooltip: 'Generate PDF Report',
                onTap: _generatePDFReport,
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? const ShimmerSkeleton()
                : Column(
                    children: [
                      const SizedBox(height: 20),
                      if (_budgetAlerts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: BudgetAlertBanner(alerts: _budgetAlerts),
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                                child: _buildPeriodButton('This Month')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _buildPeriodButton('This Year')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _buildPeriodButton('All Time')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            StaggeredListItem(
                              index: 0,
                              child: AnimatedGradientCard(
                                title: 'Balance',
                                amount: _balance,
                                icon: Icons.account_balance_wallet,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: StaggeredListItem(
                                    index: 1,
                                    child: ScaleTap(
                                      onTap: () => _navigateAndRefresh(
                                          IncomeScreen()),
                                      child: _IncomeExpenseCard(
                                        title: 'Income',
                                        amount: _totalIncome,
                                        icon: Icons.arrow_downward,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: StaggeredListItem(
                                    index: 2,
                                    child: ScaleTap(
                                      onTap: () => _navigateAndRefresh(
                                          ExpenseScreen()),
                                      child: _IncomeExpenseCard(
                                        title: 'Expense',
                                        amount: _totalExpense,
                                        icon: Icons.arrow_upward,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: StaggeredListItem(
                                index: 3,
                                child: _QuickAddButton(
                                  label: '+ Add Income',
                                  color: Colors.green,
                                  icon: Icons.arrow_downward,
                                  onTap: () =>
                                      _navigateAndRefresh(IncomeScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StaggeredListItem(
                                index: 4,
                                child: _QuickAddButton(
                                  label: '+ Add Expense',
                                  color: Colors.red,
                                  icon: Icons.arrow_upward,
                                  onTap: () =>
                                      _navigateAndRefresh(ExpenseScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_filteredTransactions.isNotEmpty)
                        StaggeredListItem(
                          index: 5,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            child: ChartWidget(
                              transactions: _filteredTransactions
                                  .where((t) => t.type == 'expense')
                                  .toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      StaggeredListItem(
                        index: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          child: RecentTransactions(
                            transactions: _filteredTransactions,
                            onRefresh: _loadData,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return _AnimatedPressButton(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _filterTransactionsByPeriod();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Center(
          child: Text(
            period,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[800]!, Colors.blue[600]!],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 180,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8)
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0x40FFFFFF),
                      child: Icon(Icons.person,
                          size: 44, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer<AuthService>(
                    builder: (context, auth, _) => Text(
                      auth.userName ?? _userName ?? 'User',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  AnimatedDrawerItem(
                    index: 0,
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    color: Colors.blue,
                    onTap: () => Navigator.pop(context),
                  ),
                  AnimatedDrawerItem(
                    index: 1,
                    icon: Icons.arrow_downward,
                    title: 'Income',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateAndRefresh(IncomeScreen());
                    },
                  ),
                  AnimatedDrawerItem(
                    index: 2,
                    icon: Icons.arrow_upward,
                    title: 'Expenses',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateAndRefresh(ExpenseScreen());
                    },
                  ),
                  AnimatedDrawerItem(
                    index: 3,
                    icon: Icons.account_balance_wallet,
                    title: 'Budget',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          SlidePageRoute(page: BudgetScreen()));
                    },
                  ),
                  AnimatedDrawerItem(
                    index: 4,
                    icon: Icons.settings,
                    title: 'Settings',
                    color: Colors.grey[700]!,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          SlidePageRoute(
                              page: const SettingsScreen()));
                    },
                  ),
                  const Divider(height: 32, indent: 16, endIndent: 16),
                  AnimatedDrawerItem(
                    index: 5,
                    icon: Icons.logout,
                    title: 'Logout',
                    color: Colors.red,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16)),
                          title: const Text('Logout'),
                          content: const Text(
                              'Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                final authService =
                                    Provider.of<AuthService>(
                                        context,
                                        listen: false);
                                authService.logout();
                                Navigator.pop(ctx);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Income/Expense Card ──────────────────────────────────────────────────────
class _IncomeExpenseCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _IncomeExpenseCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedCountUp(
            value: amount,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Add Button ─────────────────────────────────────────────────────────
class _QuickAddButton extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<_QuickAddButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPressButton(
      {required this.child, required this.onTap});

  @override
  State<_AnimatedPressButton> createState() =>
      _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasBadge;
  final int badgeCount;
  final Color badgeColor;

  const _AnimatedIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hasBadge = false,
    this.badgeCount = 0,
    this.badgeColor = Colors.red,
  });

  @override
  State<_AnimatedIconButton> createState() =>
      _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.85),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 130),
        child: Tooltip(
          message: widget.tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(widget.icon, color: Colors.white),
                if (widget.hasBadge && widget.badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: widget.badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        widget.badgeCount > 9
                            ? '9+'
                            : '${widget.badgeCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANIMATION WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class AnimatedCountUp extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final String prefix;

  const AnimatedCountUp({
    Key? key,
    required this.value,
    this.style,
    this.prefix = '৳',
  }) : super(key: key);

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200));
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
        CurvedAnimation(
            parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _animation =
          Tween<double>(begin: _previousValue, end: widget.value)
              .animate(CurvedAnimation(
                  parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
    _previousValue = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Text(
        '${widget.prefix}${_animation.value.toStringAsFixed(2)}',
        style: widget.style,
      ),
    );
  }
}

class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({Key? key}) : super(key: key);

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400))
      ..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shimmerBox({required double height, double? width}) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor =
        isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment(_animation.value - 1, 0),
          end: Alignment(_animation.value, 0),
          colors: [baseColor, highlightColor, baseColor],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 20),
          child: Column(
            children: [
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: i < 2 ? 8 : 0),
                      child: _shimmerBox(height: 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _shimmerBox(height: 100, width: double.infinity),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 80)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(height: 80)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 50)),
                  const SizedBox(width: 12),
                  Expanded(child: _shimmerBox(height: 50)),
                ],
              ),
              const SizedBox(height: 24),
              _shimmerBox(height: 200, width: double.infinity),
              const SizedBox(height: 24),
              ...List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _shimmerBox(
                      height: 60, width: double.infinity),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;

  const StaggeredListItem({
    Key? key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 80),
  }) : super(key: key);

  @override
  State<StaggeredListItem> createState() =>
      _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.baseDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child:
          SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const ScaleTap({
    Key? key,
    required this.child,
    required this.onTap,
    this.scale = 0.95,
  }) : super(key: key);

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child:
          ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

class AnimatedGradientCard extends StatefulWidget {
  final String title;
  final double amount;
  final IconData icon;

  const AnimatedGradientCard({
    Key? key,
    required this.title,
    required this.amount,
    required this.icon,
  }) : super(key: key);

  @override
  State<AnimatedGradientCard> createState() =>
      _AnimatedGradientCardState();
}

class _AnimatedGradientCardState extends State<AnimatedGradientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 0.6, -1 + t * 0.4),
              end: Alignment(1 - t * 0.4, 1 - t * 0.6),
              colors: [
                Colors.blue[900]!,
                Colors.blue[600]!,
                Colors.cyan[500]!
              ],
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedCountUp(
                value: widget.amount,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text('Total Balance',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedDrawerItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final int index;

  const AnimatedDrawerItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    required this.index,
  }) : super(key: key);

  @override
  State<AnimatedDrawerItem> createState() =>
      _AnimatedDrawerItemState();
}

class _AnimatedDrawerItemState extends State<AnimatedDrawerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _controller, curve: Curves.easeOutCubic));
    _fade =
        Tween<double>(begin: 0, end: 1).animate(_controller);
    Future.delayed(
        Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 3),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              splashColor:
                  widget.color.withOpacity(0.15),
              highlightColor:
                  widget.color.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color
                            .withOpacity(0.12),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon,
                          color: widget.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w500)),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PulseDot extends StatefulWidget {
  final Color color;
  const PulseDot(
      {Key? key, this.color = Colors.greenAccent})
      : super(key: key);

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(
        CurvedAnimation(
            parent: _controller, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.3)
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final AxisDirection direction;

  SlidePageRoute({
    required this.page,
    this.direction = AxisDirection.left,
  }) : super(
          transitionDuration:
              const Duration(milliseconds: 300),
          reverseTransitionDuration:
              const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder:
              (_, animation, secondaryAnimation, child) {
            final begin =
                direction == AxisDirection.left
                    ? const Offset(1.0, 0.0)
                    : direction == AxisDirection.up
                        ? const Offset(0.0, 1.0)
                        : const Offset(-1.0, 0.0);

            final slide = Tween<Offset>(
                    begin: begin, end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic));

            final fade =
                Tween<double>(begin: 0.0, end: 1.0)
                    .animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.6,
                      curve: Curves.easeOut),
                ));

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                  position: slide, child: child),
            );
          },
        );
}