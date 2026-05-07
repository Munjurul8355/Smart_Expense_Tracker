import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/transaction.dart';

class ExcelExport {
  static Future<void> exportTransactions(
    List<Transaction> transactions,
    String type,
  ) async {
    final excelFile = Excel.createExcel();
    final sheet = excelFile['Sheet1'];

    // Add headers
    sheet.appendRow([
      TextCellValue('Title'),
      TextCellValue('Category'),
      TextCellValue('Amount (Tk)'),
      TextCellValue('Date'),
      TextCellValue('Type'),
    ]);

    // Add data
    for (var transaction in transactions) {
      sheet.appendRow([
        TextCellValue(transaction.title),
        TextCellValue(transaction.category),
        DoubleCellValue(transaction.amount),
        TextCellValue(DateFormat('yyyy-MM-dd').format(transaction.date)),
        TextCellValue(transaction.type),
      ]);
    }

    // Style headers
    for (var i = 0; i < 5; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = CellStyle(bold: true);
    }

    // Save to phone storage
    final fileBytes = excelFile.save();
    if (fileBytes != null) {
      final fileName =
          '${type}_report_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.xlsx';
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      print('File saved: ${file.path}');
    }
  }
}