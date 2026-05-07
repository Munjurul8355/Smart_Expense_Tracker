// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/pdf_service.dart';

/// Call this function wherever your download button is:
///
///   onPressed: () => showPDFDownloadDialog(context, transactions),
///
Future<void> showPDFDownloadDialog(
  BuildContext context,
  List<Transaction> transactions,
) async {
  final now = DateTime.now();

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => _PDFDownloadDialog(
      transactions: transactions,
      now: now,
    ),
  );
}

class _PDFDownloadDialog extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime now;

  const _PDFDownloadDialog({
    required this.transactions,
    required this.now,
  });

  @override
  State<_PDFDownloadDialog> createState() => _PDFDownloadDialogState();
}

class _PDFDownloadDialogState extends State<_PDFDownloadDialog> {
  bool _isLoading = false;
  String _loadingText = '';

  Future<void> _downloadMonthly() async {
    setState(() {
      _isLoading = true;
      _loadingText = 'Generating monthly report...';
    });

    try {
      final pdfData = await PDFService.generateMonthlyReport(
        transactions: widget.transactions,
        month: widget.now.month,
        year: widget.now.year,
      );
      await PDFService.savePDF(
        pdfData,
        'report_${DateFormat('MMMM_yyyy').format(widget.now)}.pdf',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadYearly() async {
    setState(() {
      _isLoading = true;
      _loadingText = 'Generating yearly report...';
    });

    try {
      final pdfData = await PDFService.generateYearlyReport(
        transactions: widget.transactions,
        year: widget.now.year,
      );
      await PDFService.savePDF(
        pdfData,
        'report_${widget.now.year}.pdf',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.picture_as_pdf,
                color: Colors.red.shade600, size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'Download Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: _isLoading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _loadingText,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'কোন ধরনের রিপোর্ট ডাউনলোড করবেন?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Monthly Button
                _DownloadOptionButton(
                  icon: Icons.calendar_month,
                  label: 'Monthly Report',
                  subtitle:
                      DateFormat('MMMM yyyy').format(widget.now),
                  color: Colors.blue,
                  onTap: _downloadMonthly,
                ),
                const SizedBox(height: 12),

                // Yearly Button
                _DownloadOptionButton(
                  icon: Icons.calendar_today,
                  label: 'Yearly Report',
                  subtitle: '${widget.now.year} - Full Year',
                  color: Colors.green,
                  onTap: _downloadYearly,
                ),
              ],
            ),
      actions: _isLoading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
    );
  }
}

class _DownloadOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DownloadOptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}