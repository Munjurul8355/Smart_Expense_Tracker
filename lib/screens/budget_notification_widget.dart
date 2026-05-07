import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/budget_service.dart';

class BudgetAlert {
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final double percentage;
  final BudgetAlertType type;

  BudgetAlert({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.percentage,
    required this.type,
  });

  double get remaining => budgetAmount - spentAmount;
}

enum BudgetAlertType { exceeded, warning }

// ─── Global dismiss key (month-based) ────────────────────────────────────────
String _globalDismissedKey() {
  final now = DateTime.now();
  final monthTag = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return 'budget_dialog_dismissed_$monthTag';
}

// ─── Auto-refresh service ─────────────────────────────────────────────────────
class BudgetAutoRefreshService {
  Timer? _timer;
  bool _isDialogShowing = false; // ✅ Prevent duplicate dialogs

  void start(
    BuildContext context,
    List<Transaction> Function() transactionsGetter, {
    Duration interval = const Duration(minutes: 5),
    required void Function(List<BudgetAlert> alerts) onAlertsFound,
  }) {
    _runCheck(context, transactionsGetter(), onAlertsFound);
    _timer = Timer.periodic(interval, (_) {
      if (context.mounted) {
        _runCheck(context, transactionsGetter(), onAlertsFound);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runCheck(
    BuildContext context,
    List<Transaction> transactions,
    void Function(List<BudgetAlert>) onAlertsFound,
  ) async {
    if (_isDialogShowing) return; // ✅ Skip if already showing

    final alerts =
        await BudgetNotificationChecker._fetchAlerts(context, transactions);
    if (alerts.isNotEmpty) {
      onAlertsFound(alerts);
      if (context.mounted) {
        _isDialogShowing = true;
        await BudgetNotificationChecker._showIfNotDismissed(context, alerts);
        _isDialogShowing = false;
      }
    }
  }
}

// ─── Main checker ─────────────────────────────────────────────────────────────
class BudgetNotificationChecker {
  static bool _isDialogShowing = false; // ✅ Static guard against duplicates

  static Future<void> check(
      BuildContext context, List<Transaction> transactions) async {
    if (_isDialogShowing) return; // ✅ Don't show if already open

    final alerts = await _fetchAlerts(context, transactions);
    if (alerts.isNotEmpty && context.mounted) {
      _isDialogShowing = true;
      await _showIfNotDismissed(context, alerts);
      _isDialogShowing = false;
    }
  }

  /// Shows dialog only if the user hasn't dismissed this month's alert session.
  static Future<void> _showIfNotDismissed(
      BuildContext context, List<BudgetAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final globalKey = _globalDismissedKey();

    // ✅ If already dismissed this month → skip
    if (prefs.getBool(globalKey) == true) return;

    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false, // ✅ Force user to tap button or X
        builder: (_) => BudgetAlertDialog(alerts: alerts),
      );
    }
  }

  static Future<List<BudgetAlert>> _fetchAlerts(
    BuildContext context,
    List<Transaction> transactions,
  ) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final budgetService = BudgetService(userId);
      final budgets = await budgetService.getBudgets();

      // ✅ Only consider transactions from the CURRENT month
      final now = DateTime.now();
      final currentMonthTransactions = transactions.where((t) {
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

        if (percentage >= 100) {
          alerts.add(BudgetAlert(
            category: budget.category,
            budgetAmount: budget.amount,
            spentAmount: spent,
            percentage: percentage,
            type: BudgetAlertType.exceeded,
          ));
        } else if (percentage >= 80) {
          alerts.add(BudgetAlert(
            category: budget.category,
            budgetAmount: budget.amount,
            spentAmount: spent,
            percentage: percentage,
            type: BudgetAlertType.warning,
          ));
        }
      }

      return alerts;
    } catch (e) {
      debugPrint('Budget check error: $e');
      return [];
    }
  }
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class BudgetAlertDialog extends StatefulWidget {
  final List<BudgetAlert> alerts;

  const BudgetAlertDialog({Key? key, required this.alerts}) : super(key: key);

  @override
  State<BudgetAlertDialog> createState() => _BudgetAlertDialogState();
}

class _BudgetAlertDialogState extends State<BudgetAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  int get _exceededCount =>
      widget.alerts.where((a) => a.type == BudgetAlertType.exceeded).length;
  int get _warningCount =>
      widget.alerts.where((a) => a.type == BudgetAlertType.warning).length;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✅ Save dismissed state → popup never comes back this month
  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalDismissedKey(), true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _exceededCount > 0
                        ? [Colors.red[700]!, Colors.red[500]!]
                        : [Colors.orange[700]!, Colors.orange[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _exceededCount > 0
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_active,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Budget Alert!',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(_buildSubtitle(),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    // ✅ Close X also saves dismissed state
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Alert cards ─────────────────────────────────────────────
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: widget.alerts
                        .asMap()
                        .entries
                        .map((e) =>
                            _BudgetAlertCard(alert: e.value, index: e.key))
                        .toList(),
                  ),
                ),
              ),

              // ── Button ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _dismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _exceededCount > 0
                          ? Colors.red[600]
                          : Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("Got it, I'll manage!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    if (_exceededCount > 0 && _warningCount > 0) {
      return '$_exceededCount exceeded • $_warningCount near limit';
    } else if (_exceededCount > 0) {
      return '$_exceededCount budget${_exceededCount > 1 ? 's' : ''} exceeded!';
    } else {
      return '$_warningCount budget${_warningCount > 1 ? 's' : ''} near limit (80%+)';
    }
  }
}

// ─── Alert card ───────────────────────────────────────────────────────────────
class _BudgetAlertCard extends StatefulWidget {
  final BudgetAlert alert;
  final int index;

  const _BudgetAlertCard({required this.alert, required this.index});

  @override
  State<_BudgetAlertCard> createState() => _BudgetAlertCardState();
}

class _BudgetAlertCardState extends State<_BudgetAlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  late Animation<double> _slideAnim;

  bool get _isExceeded => widget.alert.type == BudgetAlertType.exceeded;
  Color get _alertColor => _isExceeded ? Colors.red : Colors.orange;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _progressAnim = Tween<double>(
      begin: 0,
      end: (widget.alert.percentage / 100).clamp(0.0, 1.0),
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _slideAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Opacity(
          opacity: _slideAnim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _slideAnim.value)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _alertColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _alertColor.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _alertColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isExceeded
                              ? Icons.money_off_csred
                              : Icons.trending_up,
                          color: _alertColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.alert.category,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      _AlertBadge(
                          label: _isExceeded ? 'Exceeded!' : 'Warning',
                          color: _alertColor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progressAnim.value,
                      minHeight: 8,
                      backgroundColor: _alertColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(_alertColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${widget.alert.percentage.toStringAsFixed(1)}% used',
                      style: TextStyle(
                          color: _alertColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _AmountChip(
                          label: 'Budget',
                          amount: widget.alert.budgetAmount,
                          color: Colors.blue),
                      const SizedBox(width: 6),
                      _AmountChip(
                          label: 'Spent',
                          amount: widget.alert.spentAmount,
                          color: _alertColor),
                      const SizedBox(width: 6),
                      _AmountChip(
                        label: _isExceeded ? 'Over' : 'Left',
                        amount: _isExceeded
                            ? widget.alert.spentAmount -
                                widget.alert.budgetAmount
                            : widget.alert.remaining,
                        color: _isExceeded ? Colors.red : Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Badge & Chip ─────────────────────────────────────────────────────────────
class _AlertBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _AlertBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountChip(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
            const SizedBox(height: 2),
            Text('৳${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────
class BudgetAlertBanner extends StatefulWidget {
  final List<BudgetAlert> alerts;

  const BudgetAlertBanner({Key? key, required this.alerts}) : super(key: key);

  @override
  State<BudgetAlertBanner> createState() => _BudgetAlertBannerState();
}

class _BudgetAlertBannerState extends State<BudgetAlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  bool _dismissed = false;

  bool get _hasExceeded =>
      widget.alerts.any((a) => a.type == BudgetAlertType.exceeded);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BudgetAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alerts != oldWidget.alerts && widget.alerts.isNotEmpty) {
      setState(() => _dismissed = false);
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || widget.alerts.isEmpty) return const SizedBox.shrink();
    final color = _hasExceeded ? Colors.red : Colors.orange;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(
              _hasExceeded
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _hasExceeded
                    ? '${widget.alerts.where((a) => a.type == BudgetAlertType.exceeded).length} budget(s) exceeded this month!'
                    : '${widget.alerts.length} budget(s) are near the limit!',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => BudgetAlertDialog(alerts: widget.alerts),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('View',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(Icons.close, color: color, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}