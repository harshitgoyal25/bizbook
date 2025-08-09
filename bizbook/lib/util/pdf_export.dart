import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:bizbook/backend/sale_model.dart';

class PdfExportUtil {
  // Add these methods to your existing PdfExportUtil class

  static Future<File> generateDailySalesReport(
      List<Sale> sales, double totalRevenue, int newCustomers) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFont);

    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final today = DateFormat('MMMM d, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) =>
            _buildReportHeader('Daily Sales Report - $today', ttf, boldTtf),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildDailySummary(
              sales, totalRevenue, newCustomers, currencyFormat, ttf, boldTtf),
          pw.SizedBox(height: 20),
          _buildSalesTable(
              sales, dateFormat, timeFormat, currencyFormat, ttf, boldTtf),
        ],
      ),
    );

    return _saveDocument(
        'Daily_Sales_Report_${DateFormat('yyyy_MM_dd').format(DateTime.now())}',
        pdf);
  }

  static Future<File> generateMonthlySalesReport(
      List<Sale> sales, double totalRevenue, int uniqueCustomers) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFont);

    final dateFormat = DateFormat('MMMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final monthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    // Group sales by date
    final Map<String, List<Sale>> salesByDate = {};
    for (var sale in sales) {
      final dateKey = DateFormat('yyyy-MM-dd').format(sale.date);
      if (!salesByDate.containsKey(dateKey)) {
        salesByDate[dateKey] = [];
      }
      salesByDate[dateKey]!.add(sale);
    }

    // Calculate daily totals
    final List<Map<String, dynamic>> dailyTotals = [];
    salesByDate.forEach((date, salesList) {
      final dailyTotal = salesList.fold(0.0, (sum, sale) => sum + sale.amount);
      final salesCount = salesList.length;
      dailyTotals.add({
        'date': DateTime.parse(date),
        'total': dailyTotal,
        'count': salesCount,
      });
    });

    // Sort by date
    dailyTotals.sort((a, b) => a['date'].compareTo(b['date']));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader(
            'Monthly Sales Report - $monthYear', ttf, boldTtf),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildMonthlySummary(sales, totalRevenue, uniqueCustomers,
              currencyFormat, ttf, boldTtf),
          pw.SizedBox(height: 20),
          _buildDailyTotalsTable(
              dailyTotals, dateFormat, currencyFormat, ttf, boldTtf),
          pw.SizedBox(height: 20),
          _buildTopCustomersTable(sales, currencyFormat, ttf, boldTtf),
        ],
      ),
    );

    return _saveDocument(
        'Monthly_Sales_Report_${DateFormat('yyyy_MM').format(DateTime.now())}',
        pdf);
  }

  static pw.Widget _buildDailySummary(
      List<Sale> sales,
      double totalRevenue,
      int newCustomers,
      NumberFormat currencyFormat,
      pw.Font ttf,
      pw.Font boldTtf) {
    // Calculate summary statistics
    final totalSales = sales.length;
    final averageSaleAmount = totalSales > 0 ? totalRevenue / totalSales : 0.0;

    // Count total items sold
    int totalItemsSold = 0;
    for (var sale in sales) {
      for (var item in sale.items) {
        totalItemsSold += item.quantity;
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Daily Summary',
            style: pw.TextStyle(font: boldTtf, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Sales:', style: pw.TextStyle(font: ttf)),
              pw.Text('$totalSales', style: pw.TextStyle(font: boldTtf)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Revenue:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                currencyFormat.format(totalRevenue),
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Average Sale Amount:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                currencyFormat.format(averageSaleAmount),
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('New Customers Today:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                '$newCustomers',
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Items Sold:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                '$totalItemsSold',
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMonthlySummary(
      List<Sale> sales,
      double totalRevenue,
      int uniqueCustomers,
      NumberFormat currencyFormat,
      pw.Font ttf,
      pw.Font boldTtf) {
    // Calculate summary statistics
    final totalSales = sales.length;
    final averageSaleAmount = totalSales > 0 ? totalRevenue / totalSales : 0.0;

    // Count total items sold
    int totalItemsSold = 0;
    for (var sale in sales) {
      for (var item in sale.items) {
        totalItemsSold += item.quantity;
      }
    }

    // Calculate average daily sales
    final now = DateTime.now();
    // final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    final avgDailySales = totalSales / daysPassed;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Monthly Summary',
            style: pw.TextStyle(font: boldTtf, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Sales:', style: pw.TextStyle(font: ttf)),
              pw.Text('$totalSales', style: pw.TextStyle(font: boldTtf)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Revenue:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                currencyFormat.format(totalRevenue),
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Average Sale Amount:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                currencyFormat.format(averageSaleAmount),
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Unique Customers:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                '$uniqueCustomers',
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Items Sold:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                '$totalItemsSold',
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Average Daily Sales:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                avgDailySales.toStringAsFixed(1),
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSalesTable(
      List<Sale> sales,
      DateFormat dateFormat,
      DateFormat timeFormat,
      NumberFormat currencyFormat,
      pw.Font ttf,
      pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sales Details',
          style: pw.TextStyle(font: boldTtf, fontSize: 16),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            // Table header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('#', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child:
                      pw.Text('Customer', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Time', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Items', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Amount', style: pw.TextStyle(font: boldTtf)),
                ),
              ],
            ),
            // Table rows
            ...sales.asMap().entries.map((entry) {
              final index = entry.key;
              final sale = entry.value;

              int totalItems = 0;
              for (var item in sale.items) {
                totalItems += item.quantity;
              }

              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child:
                        pw.Text('${index + 1}', style: pw.TextStyle(font: ttf)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(sale.customerName,
                        style: pw.TextStyle(font: ttf)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      timeFormat.format(sale.date),
                      style: pw.TextStyle(font: ttf),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '$totalItems',
                      style: pw.TextStyle(font: ttf),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      currencyFormat.format(sale.amount),
                      style: pw.TextStyle(font: boldTtf),
                    ),
                  ),
                ],
              );
            }),
            // Total row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Total:', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    currencyFormat.format(
                        sales.fold(0.0, (sum, sale) => sum + sale.amount)),
                    style: pw.TextStyle(font: boldTtf),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDailyTotalsTable(
      List<Map<String, dynamic>> dailyTotals,
      DateFormat dateFormat,
      NumberFormat currencyFormat,
      pw.Font ttf,
      pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Daily Sales Summary',
          style: pw.TextStyle(font: boldTtf, fontSize: 16),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            // Table header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Date', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Sales', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Revenue', style: pw.TextStyle(font: boldTtf)),
                ),
              ],
            ),
            // Table rows
            ...dailyTotals.map((day) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(dateFormat.format(day['date']),
                        style: pw.TextStyle(font: ttf)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${day['count']}',
                        style: pw.TextStyle(font: ttf)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      currencyFormat.format(day['total']),
                      style: pw.TextStyle(font: boldTtf),
                    ),
                  ),
                ],
              );
            }),
            // Total row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Total', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    '${dailyTotals.fold<int>(0, (sum, day) => sum + (day['count'] as int))}',
                    style: pw.TextStyle(font: boldTtf),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    currencyFormat.format(dailyTotals.fold(
                        0.0, (sum, day) => sum + day['total'])),
                    style: pw.TextStyle(font: boldTtf),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTopCustomersTable(List<Sale> sales,
      NumberFormat currencyFormat, pw.Font ttf, pw.Font boldTtf) {
    // Group sales by customer
    final Map<String, Map<String, dynamic>> customerSales = {};
    for (var sale in sales) {
      if (!customerSales.containsKey(sale.customerId)) {
        customerSales[sale.customerId] = {
          'name': sale.customerName,
          'total': 0.0,
          'count': 0,
        };
      }
      customerSales[sale.customerId]!['total'] += sale.amount;
      customerSales[sale.customerId]!['count'] += 1;
    }

    // Convert to list and sort by total
    final List<Map<String, dynamic>> topCustomers = customerSales.entries
        .map((entry) => {
              'id': entry.key,
              'name': entry.value['name'],
              'total': entry.value['total'],
              'count': entry.value['count'],
            })
        .toList();

    topCustomers
        .sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    // Take top 10 or less
    final displayCustomers = topCustomers.take(10).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Customers',
          style: pw.TextStyle(font: boldTtf, fontSize: 16),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Table header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Rank', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child:
                      pw.Text('Customer', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Orders', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Total Spent',
                      style: pw.TextStyle(font: boldTtf)),
                ),
              ],
            ),
            // Table rows
            ...displayCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;

              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child:
                        pw.Text('${index + 1}', style: pw.TextStyle(font: ttf)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(customer['name'],
                        style: pw.TextStyle(font: ttf)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '${customer['count']}',
                      style: pw.TextStyle(font: ttf),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      currencyFormat.format(customer['total']),
                      style: pw.TextStyle(font: boldTtf),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static Future<File> generateUnpaidOrdersReport(
      List<Map<String, dynamic>> customers, String title) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFont);

    final dateFormat = DateFormat('MMMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader(title, ttf, boldTtf),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildSummarySection(customers, currencyFormat, ttf, boldTtf),
          pw.SizedBox(height: 20),
          _buildCustomerTable(
              customers, dateFormat, currencyFormat, ttf, boldTtf),
        ],
      ),
    );

    return _saveDocument(title, pdf);
  }

  static Future<File> generateSaleDetailReport(Sale sale) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFont);

    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildReportHeader('Sale Receipt', ttf, boldTtf),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildSaleHeader(sale, dateFormat, timeFormat, ttf, boldTtf),
          pw.SizedBox(height: 20),
          _buildCustomerInfo(sale, ttf, boldTtf),
          pw.SizedBox(height: 20),
          _buildItemsTable(sale, currencyFormat, ttf, boldTtf),
          pw.SizedBox(height: 20),
          if (sale.notes.isNotEmpty) ...[
            _buildNotesSection(sale, ttf, boldTtf),
            pw.SizedBox(height: 20),
          ],
          _buildTotalSection(sale, currencyFormat, ttf, boldTtf),
        ],
      ),
    );

    return _saveDocument('Sale_Receipt_${sale.id.substring(0, 8)}', pdf);
  }

  static pw.Widget _buildReportHeader(
      String title, pw.Font ttf, pw.Font boldTtf) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: boldTtf,
              fontSize: 24,
            ),
          ),
          pw.Text(
            'BizBook',
            style: pw.TextStyle(
              font: boldTtf,
              fontSize: 24,
              color: PdfColors.brown,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font ttf) {
    return pw.Footer(
      margin: const pw.EdgeInsets.only(top: 16),
      title: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
            style: pw.TextStyle(font: ttf, fontSize: 10),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(font: ttf, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(List<Map<String, dynamic>> customers,
      NumberFormat currencyFormat, pw.Font ttf, pw.Font boldTtf) {
    double totalDue = 0;
    int totalOrders = 0;

    for (var customer in customers) {
      totalDue += (customer['totalDueAmount'] as num).toDouble();
      final unpaidOrders = customer['unpaidOrders'] as List;
      totalOrders += unpaidOrders.length;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(font: boldTtf, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Customers:', style: pw.TextStyle(font: ttf)),
              pw.Text('${customers.length}',
                  style: pw.TextStyle(font: boldTtf)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Unpaid Orders:', style: pw.TextStyle(font: ttf)),
              pw.Text('$totalOrders', style: pw.TextStyle(font: boldTtf)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Amount Due:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                currencyFormat.format(totalDue),
                style: pw.TextStyle(font: boldTtf),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerTable(
      List<Map<String, dynamic>> customers,
      DateFormat dateFormat,
      NumberFormat currencyFormat,
      pw.Font ttf,
      pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Customers with Unpaid Orders',
          style: pw.TextStyle(font: boldTtf, fontSize: 16),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Table header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.brown100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child:
                      pw.Text('Customer', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Contact', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('Orders', style: pw.TextStyle(font: boldTtf)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child:
                      pw.Text('Amount Due', style: pw.TextStyle(font: boldTtf)),
                ),
              ],
            ),
            // Table rows
            ...customers.map((customer) {
              final unpaidOrders = customer['unpaidOrders'] as List;
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(customer['name'] ?? 'Unknown',
                            style: pw.TextStyle(font: boldTtf)),
                        pw.SizedBox(height: 2),
                        pw.Text('ID: ${customer['customerId'] ?? 'N/A'}',
                            style: pw.TextStyle(font: ttf, fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(customer['email'] ?? 'No email',
                            style: pw.TextStyle(font: ttf)),
                        pw.SizedBox(height: 2),
                        pw.Text(customer['phoneNumber'] ?? 'No phone',
                            style: pw.TextStyle(font: ttf)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '${unpaidOrders.length}',
                      style: pw.TextStyle(font: ttf),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      currencyFormat.format(customer['totalDueAmount'] ?? 0),
                      style: pw.TextStyle(font: boldTtf),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSaleHeader(Sale sale, DateFormat dateFormat,
      DateFormat timeFormat, pw.Font ttf, pw.Font boldTtf) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sale ID', style: pw.TextStyle(font: ttf)),
              pw.Text('#${sale.id.substring(0, min(8, sale.id.length))}',
                  style: pw.TextStyle(font: boldTtf)),
            ],
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date & Time', style: pw.TextStyle(font: ttf)),
              pw.Text(
                  '${dateFormat.format(sale.date)} at ${timeFormat.format(sale.date)}',
                  style: pw.TextStyle(font: boldTtf)),
            ],
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Payment Method', style: pw.TextStyle(font: ttf)),
              pw.Text(sale.paymentMethod, style: pw.TextStyle(font: boldTtf)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomerInfo(Sale sale, pw.Font ttf, pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Customer', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.brown50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 40,
                height: 40,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.white,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    sale.customerName.isNotEmpty
                        ? sale.customerName[0].toUpperCase()
                        : '?',
                    style: pw.TextStyle(font: boldTtf, fontSize: 20),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(sale.customerName,
                      style: pw.TextStyle(font: boldTtf, fontSize: 16)),
                  pw.Text('Customer ID: ${sale.customerId}',
                      style: pw.TextStyle(font: ttf)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
      Sale sale, NumberFormat currencyFormat, pw.Font ttf, pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Items', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.brown50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: sale.items.isNotEmpty
              ? pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Table header
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.brown100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Item',
                              style: pw.TextStyle(font: boldTtf)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Price',
                              style: pw.TextStyle(font: boldTtf)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Qty',
                              style: pw.TextStyle(font: boldTtf)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total',
                              style: pw.TextStyle(font: boldTtf)),
                        ),
                      ],
                    ),
                    // Table rows
                    ...sale.items.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.itemName,
                                style: pw.TextStyle(font: ttf)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              currencyFormat.format(item.price),
                              style: pw.TextStyle(font: ttf),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.quantity}',
                              style: pw.TextStyle(font: ttf),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              currencyFormat.format(item.total),
                              style: pw.TextStyle(font: boldTtf),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                )
              : pw.Padding(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Center(
                    child: pw.Text('No items found',
                        style: pw.TextStyle(font: ttf)),
                  ),
                ),
        ),
      ],
    );
  }

  static pw.Widget _buildNotesSection(Sale sale, pw.Font ttf, pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Notes', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.brown50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text(sale.notes, style: pw.TextStyle(font: ttf)),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalSection(
      Sale sale, NumberFormat currencyFormat, pw.Font ttf, pw.Font boldTtf) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Total Amount',
            style: pw.TextStyle(
                font: boldTtf, fontSize: 16, color: PdfColors.white),
          ),
          pw.Text(
            currencyFormat.format(sale.amount),
            style: pw.TextStyle(
                font: boldTtf, fontSize: 18, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  static Future<File> _saveDocument(String name, pw.Document pdf) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> openPDF(File file) async {
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Could not open the file: ${result.message}');
    }
  }

  static Future<void> sharePDF(File file) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Sharing PDF report from BizBook',
    ));
  }

  static int min(int a, int b) {
    return a < b ? a : b;
  }
}
