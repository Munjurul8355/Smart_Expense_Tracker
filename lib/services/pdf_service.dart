import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class PDFService {
  static Future<Uint8List> generateReport({
    required List<Transaction> transactions,
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    final pdf = pw.Document();

    double totalIncome = transactions
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);

    double totalExpense = transactions
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);

    double balance = totalIncome - totalExpense;

    Map<String, double> categoryTotals = {};
    for (var t in transactions.where((t) => t.type == 'expense')) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // "All Time" হলে date range লেখা হবে "Since MMM dd, yyyy"
    final isAllTime = reportType == 'All Time';
    final dateRangeText = isAllTime
        ? 'Since ${DateFormat('MMM dd, yyyy').format(startDate)}'
        : '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Expense Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Report Type: $reportType',
              style: pw.TextStyle(
                fontSize: 13,
                color: PdfColors.blue700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              dateRangeText,
              style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            pw.Text(
              'Summary',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildSummaryTable(totalIncome, totalExpense, balance),
            pw.SizedBox(height: 30),

            pw.Text(
              'Category Breakdown',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildCategoryTable(categoryTotals),
            pw.SizedBox(height: 30),

            pw.Text(
              'Transactions',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildTransactionsTable(transactions),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateMonthlyReport({
    required List<Transaction> transactions,
    required int month,
    required int year,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final filtered = transactions
        .where((t) =>
            t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    return generateReport(
      transactions: filtered,
      startDate: startDate,
      endDate: endDate,
      reportType: 'Monthly - ${DateFormat('MMMM yyyy').format(startDate)}',
    );
  }

  static Future<Uint8List> generateYearlyReport({
    required List<Transaction> transactions,
    required int year,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    final filtered =
        transactions.where((t) => t.date.year == year).toList();

    return generateReport(
      transactions: filtered,
      startDate: startDate,
      endDate: endDate,
      reportType: 'Yearly - $year',
    );
  }

  static pw.Widget _buildSummaryTable(
    double income,
    double expense,
    double balance,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        _buildTableRow(
          'Total Income',
          'Tk ${income.toStringAsFixed(2)}',
          isHeader: true,
          color: PdfColors.green50,
        ),
        _buildTableRow(
          'Total Expense',
          'Tk ${expense.toStringAsFixed(2)}',
          isHeader: true,
          color: PdfColors.red50,
        ),
        _buildTableRow(
          'Balance',
          'Tk ${balance.toStringAsFixed(2)}',
          isHeader: true,
          isBalance: true,
          color: PdfColors.blue50,
        ),
      ],
    );
  }

  static pw.Widget _buildCategoryTable(Map<String, double> categoryTotals) {
    List<pw.TableRow> rows = [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('Category',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('Amount',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('Percentage',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    ];

    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);

    var sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedCategories) {
      final pct = total > 0
          ? (entry.value / total * 100).toStringAsFixed(1)
          : '0.0';
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text(entry.key),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('Tk ${entry.value.toStringAsFixed(2)}'),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('$pct%'),
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  static pw.Widget _buildTransactionsTable(List<Transaction> transactions) {
    List<pw.TableRow> rows = [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _buildTableCell('Date', isHeader: true),
          _buildTableCell('Title', isHeader: true),
          _buildTableCell('Category', isHeader: true),
          _buildTableCell('Amount', isHeader: true),
          _buildTableCell('Type', isHeader: true),
        ],
      ),
    ];

    for (var t in transactions) {
      final isIncome = t.type == 'income';
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isIncome ? PdfColors.green50 : PdfColors.red50,
          ),
          children: [
            _buildTableCell(DateFormat('MMM dd').format(t.date)),
            _buildTableCell(t.title),
            _buildTableCell(t.category),
            _buildTableCell('Tk ${t.amount.toStringAsFixed(2)}'),
            _buildTableCell(t.type.toUpperCase()),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: pw.FixedColumnWidth(60),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FixedColumnWidth(80),
        4: pw.FixedColumnWidth(60),
      },
      children: rows,
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 10 : 9,
        ),
      ),
    );
  }

  static pw.TableRow _buildTableRow(
    String label,
    String value, {
    bool isHeader = false,
    bool isBalance = false,
    PdfColor? color,
  }) {
    return pw.TableRow(
      decoration: color != null ? pw.BoxDecoration(color: color) : null,
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(12),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(12),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight:
                  isBalance ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 14,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static Future<void> savePDF(Uint8List pdfData, String filename) async {
    await Printing.sharePdf(bytes: pdfData, filename: filename);
  }

  static Future<void> printPDF(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    );
  }
}