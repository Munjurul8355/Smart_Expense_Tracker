import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection(context, title: 'Appearance', children: [
            Consumer<ThemeService>(
              builder: (context, themeService, _) {
                return _AnimatedTile(
                  child: SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use dark theme'),
                    value: themeService.isDarkMode,
                    onChanged: (_) => themeService.toggleTheme(),
                    secondary: Icon(themeService.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode),
                  ),
                );
              },
            ),
          ]),
          const Divider(),
          _buildSection(context, title: 'Account', children: [
            _AnimatedTile(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                subtitle: const Text('Manage your profile'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ),
            _AnimatedTile(
              child: ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categories'),
                subtitle: const Text('Manage custom categories'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoriesScreen())),
              ),
            ),
          ]),
          const Divider(),
          _buildSection(context, title: 'Data', children: [
            _AnimatedTile(
              child: ListTile(
                leading: const Icon(Icons.backup, color: Colors.blue),
                title: const Text('Backup Data'),
                subtitle: const Text('Export your transactions as JSON'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _backupData(context),
              ),
            ),
            _AnimatedTile(
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Clear All Data',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete all transactions'),
                onTap: () => _showClearDataDialog(context),
              ),
            ),
          ]),
          const Divider(),
          _buildSection(context, title: 'About', children: [
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('App Version'),
              subtitle: Text('1.0.0'),
            ),
            _AnimatedTile(
              child: ListTile(
                leading: const Icon(Icons.help, color: Colors.blue),
                title: const Text('Help & Support'),
                subtitle: const Text('FAQs and contact us'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HelpSupportScreen())),
              ),
            ),
            _AnimatedTile(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.green),
                title: const Text('Privacy Policy'),
                subtitle: const Text('How we handle your data'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen())),
              ),
            ),
          ]),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _AnimatedPressButton(
              onTap: () => _showLogoutDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Logout',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.5)),
        ),
        ...children,
      ],
    );
  }

  Future<void> _backupData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Preparing backup...'),
        ]),
      ),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final transactionService = TransactionService(userId);
      final List<Transaction> transactions =
          await transactionService.getTransactions();

      final List<Map<String, dynamic>> jsonList = transactions.map((t) {
        return {
          'id': t.id,
          'type': t.type,
          'amount': t.amount,
          'category': t.category,
          'description': t.description,
          'date': t.date.toIso8601String(),
        };
      }).toList();

      final Map<String, dynamic> backupData = {
        'app': 'Expense Tracker',
        'exported_at': DateTime.now().toIso8601String(),
        'user': authService.userEmail ?? '',
        'total_transactions': transactions.length,
        'transactions': jsonList,
      };

      final String jsonString =
          const JsonEncoder.withIndent('  ').convert(backupData);
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'expense_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final File file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      if (context.mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Expense Tracker Backup — ${transactions.length} transactions exported',
        subject: 'Expense Tracker Backup',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Backup failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              authService.logout();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Clear All Data', style: TextStyle(color: Colors.red)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete ALL your transactions. This action cannot be undone.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text('Type DELETE to confirm:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: confirmController.text == 'DELETE'
                    ? () async {
                        Navigator.pop(dialogContext);
                        await _clearAllData(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red.withOpacity(0.3),
                ),
                child: const Text('Clear All',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: Colors.red),
          SizedBox(width: 16),
          Text('Deleting all data...'),
        ]),
      ),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final transactionService = TransactionService(userId);
      final List<Transaction> transactions =
          await transactionService.getTransactions();

      int deletedCount = 0;
      int failedCount = 0;

      for (final transaction in transactions) {
        final success =
            await transactionService.deleteTransaction(transaction.id);
        if (success) {
          deletedCount++;
        } else {
          failedCount++;
        }
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        if (failedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('$deletedCount transactions deleted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$deletedCount deleted, $failedCount failed. Try again.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  HELP & SUPPORT SCREEN
// ═══════════════════════════════════════════════════════════════════

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I add a transaction?',
      'a':
          'Go to the Dashboard and tap "+ Add Income" or "+ Add Expense". Fill in the amount, category, and description, then tap Save.',
    },
    {
      'q': 'How do I set a budget?',
      'a':
          'Open the drawer menu and tap "Budget". Then tap the "+" button to create a new budget for any category.',
    },
    {
      'q': 'Why am I getting budget alerts?',
      'a':
          'Budget alerts appear when you have spent 80% or more of your set budget for a category in the current month. Tap "Got it" to dismiss for the month.',
    },
    {
      'q': 'How do I export my data?',
      'a':
          'Go to Settings → Backup Data. Your transactions will be exported as a JSON file which you can save or share.',
    },
    {
      'q': 'Can I delete a transaction?',
      'a':
          'Yes. Go to the Income or Expense screen, swipe left on a transaction or tap it to see the delete option.',
    },
    {
      'q': 'How do I change my name?',
      'a':
          'Go to Settings → Profile. Tap the edit (pencil) icon next to your name, type the new name, and tap Save.',
    },
    {
      'q': 'Is my data secure?',
      'a':
          'Yes. Your data is stored securely on Firebase Firestore with your account credentials. Only you can access your transactions.',
    },
    {
      'q': 'How do I switch between dark and light mode?',
      'a':
          'Go to Settings → Appearance and toggle the "Dark Mode" switch.',
    },
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      const Text('Help & Support',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('We\'re here to help you',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Contact Cards ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ContactCard(
                          icon: Icons.email_outlined,
                          label: 'Email Us',
                          value: 'support@expensetracker.app',
                          color: Colors.blue,
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content:
                                      Text('Opening email client...'))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ContactCard(
                          icon: Icons.chat_bubble_outline,
                          label: 'Live Chat',
                          value: 'Available 9am–6pm',
                          color: Colors.green,
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text('Chat coming soon!'))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── FAQ Section ──────────────────────────────────────
                  Text('Frequently Asked Questions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  ...List.generate(_faqs.length, (i) {
                    final isExpanded = _expandedIndex == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[850]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isExpanded
                              ? Colors.blue.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() =>
                            _expandedIndex = isExpanded ? null : i),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.blue.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.help_outline,
                                        color: Colors.blue, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _faqs[i]['q']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration:
                                        const Duration(milliseconds: 250),
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: isExpanded
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              if (isExpanded) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.blue.withOpacity(0.06),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _faqs[i]['a']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.6,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // ── Still need help? ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.headset_mic,
                            color: Colors.white, size: 32),
                        const SizedBox(height: 10),
                        const Text('Still need help?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Our support team typically responds within 24 hours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Opening email client...'))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Contact Support',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PRIVACY POLICY SCREEN
// ═══════════════════════════════════════════════════════════════════

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sections = [
      _PolicySection(
        icon: Icons.info_outline,
        color: Colors.blue,
        title: 'Information We Collect',
        content:
            'We collect information you provide directly to us, such as your name, email address, and financial transaction data (amounts, categories, descriptions, and dates). We do not collect any payment card or bank account information.',
      ),
      _PolicySection(
        icon: Icons.storage_outlined,
        color: Colors.purple,
        title: 'How We Store Your Data',
        content:
            'Your data is securely stored using Google Firebase Firestore, a cloud-based NoSQL database. All data is encrypted in transit and at rest. Each user\'s data is isolated and accessible only through authenticated sessions.',
      ),
      _PolicySection(
        icon: Icons.visibility_outlined,
        color: Colors.orange,
        title: 'How We Use Your Information',
        content:
            'We use your information solely to provide and improve the Expense Tracker service. This includes displaying your transactions, calculating budgets, generating reports, and personalizing your experience. We do not use your data for advertising purposes.',
      ),
      _PolicySection(
        icon: Icons.share_outlined,
        color: Colors.red,
        title: 'Data Sharing',
        content:
            'We do not sell, trade, or share your personal information with third parties. Your financial data remains private and is never used for marketing or shared with advertisers.',
      ),
      _PolicySection(
        icon: Icons.lock_outline,
        color: Colors.green,
        title: 'Data Security',
        content:
            'We implement industry-standard security measures including HTTPS encryption, Firebase Authentication, and Firestore Security Rules to protect your data. Access to your account requires email and password authentication.',
      ),
      _PolicySection(
        icon: Icons.person_outline,
        color: Colors.teal,
        title: 'Your Rights',
        content:
            'You have the right to access, update, or delete your personal data at any time. You can export your data via Settings → Backup Data, or delete all data via Settings → Clear All Data. To permanently delete your account, contact our support team.',
      ),
      _PolicySection(
        icon: Icons.child_care_outlined,
        color: Colors.pink,
        title: 'Children\'s Privacy',
        content:
            'Expense Tracker is not intended for use by children under the age of 13. We do not knowingly collect personal information from children. If you believe a child has provided us with personal information, please contact us immediately.',
      ),
      _PolicySection(
        icon: Icons.update_outlined,
        color: Colors.indigo,
        title: 'Changes to This Policy',
        content:
            'We may update this Privacy Policy from time to time. We will notify you of any significant changes by updating the date below and, where appropriate, through in-app notifications. Continued use of the app after changes constitutes acceptance of the new policy.',
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green[800]!, Colors.green[500]!],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.privacy_tip_outlined,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 12),
                      const Text('Privacy Policy',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Last updated: May 2026',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intro card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            color: Colors.green, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your privacy matters to us. This policy explains how Expense Tracker collects, uses, and protects your information.',
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Policy sections
                  ...List.generate(sections.length, (i) {
                    final s = sections[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[850]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: s.color.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: s.color
                                        .withOpacity(0.12),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(s.icon,
                                      color: s.color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.content,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.65,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Contact footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green[700]!,
                          Colors.green[500]!
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.mail_outline,
                            color: Colors.white, size: 28),
                        const SizedBox(height: 10),
                        const Text('Questions about privacy?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Contact us at privacy@expensetracker.app',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  const _PolicySection({
    required this.icon,
    required this.color,
    required this.title,
    required this.content,
  });
}

// ═══════════════════════════════════════════════════════════════════
//  PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isEditingName = false;
  bool _isSaving = false;
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _nameController = TextEditingController(text: authService.userName ?? '');
    _emailController =
        TextEditingController(text: authService.userEmail ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    _nameFocusNode.unfocus();

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.updateName(newName);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Name updated successfully!'
          : 'Saved locally (server unreachable)'),
      backgroundColor: success ? Colors.green : Colors.orange,
    ));
  }

  void _cancelEdit() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _nameController.text = authService.userName ?? '';
    _nameFocusNode.unfocus();
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.blue[50],
                  child: Text(
                    (authService.userName ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.person,
                              color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Full Name',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500])),
                              const SizedBox(height: 4),
                              _isEditingName
                                  ? TextField(
                                      controller: _nameController,
                                      focusNode: _nameFocusNode,
                                      autofocus: true,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        border: UnderlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => _saveProfile(),
                                    )
                                  : Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text
                                          : '—',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isSaving)
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                        else if (_isEditingName) ...[
                          GestureDetector(
                            onTap: _saveProfile,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: const Text('Save',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _cancelEdit,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.grey),
                            ),
                          ),
                        ] else
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isEditingName = true),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: const Icon(Icons.edit,
                                  size: 16, color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.email,
                              color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email Address',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500])),
                              const SizedBox(height: 4),
                              Text(
                                _emailController.text.isNotEmpty
                                    ? _emailController.text
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.lock_outline,
                              size: 16, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Member Since', '2026'),
                    _buildStatDivider(),
                    _buildStatItem('Account', 'Active'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _AnimatedPressButton(
              onTap: () => _showChangePasswordDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('Change Password',
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 40, width: 1, color: Colors.grey[300]);
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Passwords do not match!'),
                        backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Password changed successfully!'),
                  backgroundColor: Colors.green));
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CATEGORIES SCREEN
// ═══════════════════════════════════════════════════════════════════

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CustomCategory> _customCategories = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _defaultIncome = [
    {'name': 'Salary', 'icon': Icons.work, 'color': Colors.green},
    {'name': 'Freelance', 'icon': Icons.laptop, 'color': Colors.teal},
    {'name': 'Investment', 'icon': Icons.trending_up, 'color': Colors.blue},
    {'name': 'Business', 'icon': Icons.store, 'color': Colors.purple},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  final List<Map<String, dynamic>> _defaultExpense = [
    {'name': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {
      'name': 'Transport',
      'icon': Icons.directions_car,
      'color': Colors.blue
    },
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    {
      'name': 'Entertainment',
      'icon': Icons.movie,
      'color': Colors.purple
    },
    {'name': 'Bills', 'icon': Icons.receipt, 'color': Colors.red},
    {
      'name': 'Healthcare',
      'icon': Icons.local_hospital,
      'color': Colors.teal
    },
    {'name': 'Education', 'icon': Icons.school, 'color': Colors.indigo},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId!;
    final categoryService = CategoryService(userId);
    final categories = await categoryService.getCustomCategories();
    setState(() {
      _customCategories = categories;
      _isLoading = false;
    });
  }

  void _showAddCategoryDialog(String type) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
            'Add ${type == 'income' ? 'Income' : 'Expense'} Category'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Rent, Bonus...',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final userId = authService.currentUserId!;
              final categoryService = CategoryService(userId);
              final newCategory = CustomCategory(
                id: '',
                userId: userId,
                name: nameCtrl.text.trim(),
                type: type,
                createdAt: DateTime.now(),
              );
              final success =
                  await categoryService.createCategory(newCategory);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Category "${nameCtrl.text.trim()}" added!'),
                  backgroundColor: Colors.green,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to add category'),
                        backgroundColor: Colors.red));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(CustomCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService =
          Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUserId!;
      final categoryService = CategoryService(userId);
      final success =
          await categoryService.deleteCategory(category.id);
      if (success) {
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${category.name}" deleted'),
            backgroundColor: Colors.red[400],
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Income'), Tab(text: 'Expense')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList('income'),
                _buildCategoryList('expense'),
              ],
            ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final type =
              _tabController.index == 0 ? 'income' : 'expense';
          return _AnimatedPressButton(
            onTap: () => _showAddCategoryDialog(type),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _tabController.index == 0
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (_tabController.index == 0
                            ? Colors.green
                            : Colors.red)
                        .withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add ${type == 'income' ? 'Income' : 'Expense'} Category',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryList(String type) {
    final defaults =
        type == 'income' ? _defaultIncome : _defaultExpense;
    final customs =
        _customCategories.where((c) => c.type == type).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('Default Categories',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ...defaults.map((cat) => _buildDefaultCategoryTile(cat)),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Custom Categories',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: type == 'income'
                    ? Colors.green[100]
                    : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${customs.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: type == 'income'
                          ? Colors.green[800]
                          : Colors.red[800])),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (customs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Icon(Icons.category_outlined,
                    size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No custom categories yet',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text('Tap + to add one',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          )
        else
          ...customs.map((cat) => _buildCustomCategoryTile(cat, type)),
      ],
    );
  }

  Widget _buildDefaultCategoryTile(Map<String, dynamic> cat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (cat['color'] as Color).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(cat['icon'] as IconData,
              color: cat['color'] as Color, size: 20),
        ),
        title: Text(cat['name'],
            style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8)),
          child: Text('Default',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
      ),
    );
  }

  Widget _buildCustomCategoryTile(CustomCategory cat, String type) {
    final color = type == 'income' ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.label, color: color, size: 20),
        ),
        title: Text(cat.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: _AnimatedPressButton(
          onTap: () => _deleteCategory(cat),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline,
                color: Colors.red, size: 18),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SHARED ANIMATED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _AnimatedTile extends StatefulWidget {
  final Widget child;
  const _AnimatedTile({required this.child});

  @override
  State<_AnimatedTile> createState() => _AnimatedTileState();
}

class _AnimatedTileState extends State<_AnimatedTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
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