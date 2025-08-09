import 'dart:io';

import 'package:bizbook/backend/auth.dart';
import 'package:bizbook/backend/sale_model.dart';
import 'package:bizbook/util/pdf_export.dart';
import 'package:bizbook/widget/appbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class UnpaidOrdersReportScreen extends StatefulWidget {
  const UnpaidOrdersReportScreen({super.key});

  @override
  State<UnpaidOrdersReportScreen> createState() =>
      _UnpaidOrdersReportScreenState();
}

class _UnpaidOrdersReportScreenState extends State<UnpaidOrdersReportScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _customersWithUnpaidOrders = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomersWithUnpaidOrders();
  }

  Future<void> _fetchCustomersWithUnpaidOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all customers
      final customersSnapshot = await _database.child('customers').get();
      final salesSnapshot = await _database.child('sales').get();

      if (customersSnapshot.exists && salesSnapshot.exists) {
        final customersData =
            Map<String, dynamic>.from(customersSnapshot.value as Map);
        final salesData = Map<String, dynamic>.from(salesSnapshot.value as Map);

        List<Map<String, dynamic>> customersWithUnpaid = [];

        // Process each customer
        customersData.forEach((customerId, customerData) {
          final customer = Map<String, dynamic>.from(customerData as Map);
          customer['id'] = customerId;

          // Find unpaid orders for this customer
          List<Map<String, dynamic>> unpaidOrders = [];
          num totalDueAmount = 0;

          salesData.forEach((salesId, salesData) {
            final sale = Map<String, dynamic>.from(salesData as Map);

            // Check if this sale belongs to the customer and is unpaid
            if (sale['customerId'] == customerId &&
                (sale['paymentMethod'] == 'Cash')) {
              sale['id'] = salesId;
              unpaidOrders.add(sale);
              totalDueAmount += num.parse(sale['amount'].toString());
            }
          });

          // Only add customers with unpaid orders
          if (unpaidOrders.isNotEmpty) {
            customer['unpaidOrders'] = unpaidOrders;
            customer['totalDueAmount'] = totalDueAmount;
            customersWithUnpaid.add(customer);
          }
        });

        setState(() {
          _customersWithUnpaidOrders = customersWithUnpaid;
          _filteredCustomers = customersWithUnpaid;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = _customersWithUnpaidOrders;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredCustomers = _customersWithUnpaidOrders.where((customer) {
        final name = customer['name']?.toString().toLowerCase() ?? '';
        final email = customer['email']?.toString().toLowerCase() ?? '';
        final phone = customer['phoneNumber']?.toString().toLowerCase() ?? '';

        return name.contains(lowercaseQuery) ||
            email.contains(lowercaseQuery) ||
            phone.contains(lowercaseQuery);
      }).toList();
    });
  }

  Future<void> _exportToPdf() async {
    if (_filteredCustomers.isEmpty) {
      AuthService().showToast(context, "No data to export", false);
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final file = await PdfExportUtil.generateUnpaidOrdersReport(
        _filteredCustomers,
        'Unpaid Orders Report',
      );

      setState(() {
        _isExporting = false;
      });

      // Show options dialog
      if (!mounted) return;
      _showPdfOptionsDialog(file);
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      if (!mounted) return;
      AuthService().showToast(context, "Failed to export PDF: $e", false);
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
                AuthService()
                    .showToast(context, "Failed to open PDF: $error", false);
              });
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PdfExportUtil.sharePDF(file).catchError((error) {
                if (!context.mounted) {
                  return; // Check if widget is still mounted
                }
                AuthService()
                    .showToast(context, "Failed to share PDF: $error", false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unpaid Orders Report"),
        backgroundColor: const Color(0xFF8D6E63),
        foregroundColor: Colors.white,
        actions: [
          // PDF Export button
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: _isExporting ? null : _exportToPdf,
          ),
        ],
      ),
      drawer: drawer(context, "Reports"),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5EFE6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterCustomers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort by: Name',
                  style: TextStyle(
                    color: Color(0xFF8D6E63),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF8D6E63),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredCustomers.length} customers',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? const Center(
                        child: Text('No customers with unpaid orders'))
                    : ListView.builder(
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          final totalDue = customer['totalDueAmount'] ?? 0;
                          final unpaidOrders = List<Map<String, dynamic>>.from(
                              customer['unpaidOrders'] as List);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            child: Card(
                              color: const Color(0xFFF5EFE6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CustomerDetailScreen(
                                        customer: customer,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Color(0xFF8D6E63),
                                        child: Text(
                                          (customer['name'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? (customer['name'] as String)
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer['name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8D6E63),
                                              ),
                                            ),
                                            Text(
                                              customer['email'] ?? 'No email',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${totalDue.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF8D6E63),
                                            ),
                                          ),
                                          Text(
                                            '${unpaidOrders.length} orders',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  final Map<String, dynamic> customer;
  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  Future<void> _sendPaymentReminder(BuildContext context) async {
    try {
      String whatsappUrl =
          'https://wa.me/${customer['phoneNumber']}?text=${Uri.encodeComponent('Dear ${customer['name']},\n\nThis is a friendly reminder that you have unpaid orders totaling ₹${customer['totalDueAmount'].toStringAsFixed(2)}. Please arrange for payment at your earliest convenience.\n\nThank you,\nBiZBook')}';

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      }
    } catch (error) {
      if (!context.mounted) return;
      AuthService().showToast(context, "Error sending reminder", false);
    }
  }

  Future<void> _exportCustomerDetailToPdf(BuildContext context) async {
    try {
      // Show loading indicator
      final loadingDialog = AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Generating PDF..."),
          ],
        ),
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => loadingDialog,
      );

      // Get unpaid orders
      final unpaidOrders =
          List<Map<String, dynamic>>.from(customer['unpaidOrders'] as List);

      // Generate PDF for each unpaid order
      if (unpaidOrders.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        AuthService().showToast(context, "No orders to export", false);
        return;
      }

      // For simplicity, we'll just export the first unpaid order
      final order = unpaidOrders.first;

      // Convert to Sale object
      final sale = Sale(
        id: order['id'] ?? '',
        customerId: customer['id'] ?? '',
        customerName: customer['name'] ?? 'Unknown',
        amount: (order['amount'] ?? 0.0).toDouble(),
        date: DateTime.parse(order['date'] ?? DateTime.now().toIso8601String()),
        items: [], // We would need to populate this from the order items
        paymentMethod: order['paymentMethod'] ?? 'Cash',
        notes: order['notes'] ?? '',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final file = await PdfExportUtil.generateSaleDetailReport(sale);
      if (!context.mounted) return;
      // Close loading dialog
      Navigator.pop(context);

      // Show options dialog
      _showPdfOptionsDialog(context, file);
    } catch (e) {
      // Close loading dialog if open
      Navigator.pop(context);
      AuthService().showToast(context, "Failed to export PDF: $e", false);
    }
  }

  void _showPdfOptionsDialog(BuildContext context, File file) {
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
                AuthService()
                    .showToast(context, "Failed to open PDF: $error", false);
              });
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PdfExportUtil.sharePDF(file).catchError((error) {
                AuthService()
                    .showToast(context, "Failed to share PDF: $error", false);
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
    final unpaidOrders =
        List<Map<String, dynamic>>.from(customer['unpaidOrders'] as List);
    final totalDue = customer['totalDueAmount'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer['name'] ?? 'Customer Details'),
        backgroundColor: Color(0xFF8D6E63),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // PDF Export button
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: () => _exportCustomerDetailToPdf(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF8D6E63),
              child: Text(
                (customer['name'] as String?)?.isNotEmpty == true
                    ? (customer['name'] as String).substring(0, 1).toUpperCase()
                    : '?',
                style: TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              customer['name'] ?? 'Unknown',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8D6E63),
              ),
            ),
            Text(
              'Customer since ${customer['createdAt'] ?? 'Unknown'}',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoCard(
                  icon: Icons.currency_rupee,
                  title: '₹${totalDue.toStringAsFixed(2)}',
                  subtitle: 'Total Due',
                ),
                _buildInfoCard(
                  icon: Icons.shopping_cart,
                  title: '${unpaidOrders.length}',
                  subtitle: 'Unpaid Orders',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: const Color(0xFFF5EFE6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContactRow(
                        icon: Icons.email,
                        title: 'Email',
                        value: customer['email'] ?? 'No email',
                      ),
                      const SizedBox(height: 12),
                      _buildContactRow(
                        icon: Icons.phone,
                        title: 'Phone',
                        value: customer['phoneNumber'] ?? 'No phone',
                      ),
                      const SizedBox(height: 12),
                      _buildContactRow(
                        icon: Icons.location_on,
                        title: 'Address',
                        value: customer['address'] ?? 'No address',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _sendPaymentReminder(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8D6E63),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Send Payment Reminder',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unpaid Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unpaidOrders.length,
              itemBuilder: (context, index) {
                final order = unpaidOrders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Card(
                    color: const Color(0xFFF5EFE6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order['id']?.toString().substring(0, 8) ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8D6E63),
                                ),
                              ),
                              Text(
                                order['date'] ?? 'Unknown date',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${order['items']?.length ?? 0} items',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                '₹${order['amount']?.toString() ?? '0.00'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8D6E63),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment: ${order['paymentMethod'] ?? 'Unknown'}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Unpaid',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Color(0xFF8D6E63), size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8D6E63),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAE0D5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF8D6E63), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
