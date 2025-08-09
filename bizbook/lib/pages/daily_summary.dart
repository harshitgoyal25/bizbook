import 'dart:io';

import 'package:bizbook/backend/sale_model.dart';
import 'package:bizbook/pages/sale_detail.dart';
import 'package:bizbook/util/pdf_export.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:bizbook/widget/appbar.dart';
import 'package:bizbook/repositories/database_repository.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  DailySummaryScreenState createState() => DailySummaryScreenState();
}

class DailySummaryScreenState extends State<DailySummaryScreen> {
  final DatabaseRepository _repository = DatabaseRepository();
  bool _isLoading = true;
  bool _isExportingDaily = false;
  bool _isExportingMonthly = false;
  int notificationCount = 1;

  // Summary data
  double _todayRevenue = 0.0;
  double _weeklyRevenue = 0.0;
  int _todaySales = 0;
  int _newCustomers = 0;
  int _totalInventory = 0;
  int _lowStockItems = 0;
  List<Sale> _recentSales = [];

  // All sales data for reports
  List<Sale> _allSales = [];

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    // Listen for changes in sales
    FirebaseDatabase.instance.ref().child('sales').onValue.listen((_) {
      _loadSummaryData();
    });

    // Listen for changes in customers
    FirebaseDatabase.instance.ref().child('customers').onValue.listen((_) {
      _loadSummaryData();
    });

    // Listen for changes in inventory
    FirebaseDatabase.instance.ref().child('inventory').onValue.listen((_) {
      _loadSummaryData();
    });
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await _repository.getDailySummary();

      // Load all sales for reports
      final salesSnapshot =
          await FirebaseDatabase.instance.ref().child('sales').get();
      List<Sale> allSales = [];

      if (salesSnapshot.exists) {
        final salesData = salesSnapshot.value as Map<dynamic, dynamic>;
        salesData.forEach((key, value) {
          final sale = Sale.fromMap(key, value as Map<dynamic, dynamic>);
          allSales.add(sale);
        });
      }

      setState(() {
        _todaySales = summary['todaySales'];
        _todayRevenue = summary['todayRevenue'];
        _weeklyRevenue = summary['weeklyRevenue'];
        _newCustomers = summary['newCustomers'];
        _totalInventory = summary['totalInventory'];
        _lowStockItems = summary['lowStockItems'];
        _recentSales = summary['recentSales'];
        _allSales = allSales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportDailySalesReport() async {
    if (_allSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales data to export')),
      );
      return;
    }

    setState(() {
      _isExportingDaily = true;
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Filter sales for today
      final todaySales = _allSales.where((sale) {
        final saleDate = DateFormat('yyyy-MM-dd').format(sale.date);
        return saleDate == today;
      }).toList();

      if (todaySales.isEmpty) {
        setState(() {
          _isExportingDaily = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales data for today')),
        );
        return;
      }

      final file = await PdfExportUtil.generateDailySalesReport(
        todaySales,
        _todayRevenue,
        _newCustomers,
      );

      setState(() {
        _isExportingDaily = false;
      });

      // Show options dialog
      _showPdfOptionsDialog(file);
    } catch (e) {
      setState(() {
        _isExportingDaily = false;
      });
      if (!mounted) return; // Check if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  Future<void> _exportMonthlySalesReport() async {
    if (_allSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales data to export')),
      );
      return;
    }

    setState(() {
      _isExportingMonthly = true;
    });

    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Filter sales for current month
      final monthlySales = _allSales.where((sale) {
        return sale.date.month == currentMonth && sale.date.year == currentYear;
      }).toList();

      if (monthlySales.isEmpty) {
        setState(() {
          _isExportingMonthly = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales data for this month')),
        );
        return;
      }

      // Calculate total monthly revenue
      final monthlyRevenue =
          monthlySales.fold(0.0, (sum, sale) => sum + sale.amount);

      // Count unique customers this month
      final Set<String> uniqueCustomers = {};
      for (var sale in monthlySales) {
        uniqueCustomers.add(sale.customerId);
      }

      final file = await PdfExportUtil.generateMonthlySalesReport(
        monthlySales,
        monthlyRevenue,
        uniqueCustomers.length,
      );

      setState(() {
        _isExportingMonthly = false;
      });

      // Show options dialog
      _showPdfOptionsDialog(file);
    } catch (e) {
      setState(() {
        _isExportingMonthly = false;
      });
      if (!mounted) return; // Check if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  void _showPdfOptionsDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Generated'),
        content: const Text(
            'Your report has been generated. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PdfExportUtil.openPDF(file).catchError((error) {
                if (!context.mounted) {
                  return; // Check if widget is still mounted
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to open PDF: $error")),
                );
              });
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PdfExportUtil.sharePDF(file).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to share PDF: $error")),
                );
              });
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      appBar: backAppBar(
        "Daily Summary",
        context,
        [
          // Daily Report Export button
          _isExportingDaily
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.today, color: Colors.white),
                  tooltip: 'Export Daily Report',
                  onPressed: _exportDailySalesReport,
                ),
          // Monthly Report Export button
          _isExportingMonthly
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.calendar_month, color: Colors.white),
                  tooltip: 'Export Monthly Report',
                  onPressed: _exportMonthlySalesReport,
                ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummaryData,
        color: const Color(0xFF7BA37E),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5E5A)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5E5A),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Revenue summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EBE6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Revenue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5E5A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Today',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF8B5E5A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormat.format(_todayRevenue),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5E5A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'This Week',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF8B5E5A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormat.format(_weeklyRevenue),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5E5A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Sales',
                            _todaySales.toString(),
                            Icons.shopping_cart,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'New Customers',
                            _newCustomers.toString(),
                            Icons.person_add,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Inventory Items',
                            _totalInventory.toString(),
                            Icons.inventory_2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Low Stock Items',
                            _lowStockItems.toString(),
                            Icons.warning_amber,
                            isWarning: _lowStockItems > 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Today\'s Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5E5A),
                          ),
                        ),
                        if (_recentSales.isNotEmpty)
                          TextButton.icon(
                            onPressed: _exportDailySalesReport,
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Export'),
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0xFF8B5E5A),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EBE6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _recentSales.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No recent transactions',
                                  style: TextStyle(
                                    color: Color(0xFF8B5E5A),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentSales.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                height: 1,
                                color: Color(0xFFE5D6CC),
                              ),
                              itemBuilder: (context, index) {
                                final sale = _recentSales[index];
                                return ListTile(
                                  title: Text(
                                    sale.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B5E5A),
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('MMM d, yyyy • h:mm a')
                                        .format(sale.date),
                                    style: TextStyle(
                                      color: Color(0xFF8B5E5A),
                                    ),
                                  ),
                                  trailing: Text(
                                    currencyFormat.format(sale.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B5E5A),
                                    ),
                                  ),
                                  onTap: () {
                                    // Navigate to sale details
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SaleDetailScreen(
                                          sale: sale,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EBE6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isWarning ? Colors.amber : const Color(0xFF8B5E5A),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B5E5A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color:
                  isWarning ? Colors.amber.shade800 : const Color(0xFF8B5E5A),
            ),
          ),
        ],
      ),
    );
  }
}
