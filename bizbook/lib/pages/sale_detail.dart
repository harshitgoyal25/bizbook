import 'dart:io';

import 'package:bizbook/backend/sale_model.dart';
import 'package:bizbook/util/pdf_export.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bizbook/widget/appbar.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;

  const SaleDetailScreen({
    super.key,
    required this.sale,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  bool isExporting = false;
  Future<void> _exportToPdf(BuildContext context) async {
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

      final file = await PdfExportUtil.generateSaleDetailReport(widget.sale);
      if (!context.mounted) {
        // If the context is no longer mounted, exit early
        return;
      }
      // Close loading dialog
      Navigator.pop(context);

      // Show options dialog
      _showPdfOptionsDialog(context, file);
    } catch (e) {
      // Close loading dialog if open
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export PDF: $e")),
      );
    }
  }

  void _showPdfOptionsDialog(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Generated'),
        content: const Text(
            'Your receipt has been generated. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PdfExportUtil.openPDF(file).catchError((error) {
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
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: backAppBar('Sale Details', context, [
        IconButton(
          icon: Icon(Icons.picture_as_pdf),
          tooltip: 'Export to PDF',
          onPressed: () => _exportToPdf(context),
        ),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sale header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EBE6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sale ID',
                        style: TextStyle(
                          color: Color(0xFF8B5E5A),
                        ),
                      ),
                      Text(
                        '#${widget.sale.id.substring(0, min(8, widget.sale.id.length))}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5E5A),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          color: Color(0xFF8B5E5A),
                        ),
                      ),
                      Text(
                        '${dateFormat.format(widget.sale.date)} at ${timeFormat.format(widget.sale.date)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5E5A),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          color: Color(0xFF8B5E5A),
                        ),
                      ),
                      Text(
                        widget.sale.paymentMethod,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5E5A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Customer information
            const Text(
              'Customer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5E5A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EBE6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Color(0xFF8B5E5A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sale.customerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5E5A),
                          ),
                        ),
                        Text(
                          'Customer ID: ${widget.sale.customerId}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Items
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5E5A),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2EBE6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.sale.items.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.sale.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = widget.sale.items[index];
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if (item.imageUrl != null &&
                                  item.imageUrl!.isNotEmpty)
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(item.imageUrl!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5E5A),
                                      ),
                                    ),
                                    Text(
                                      '₹${item.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'x${item.quantity}',
                                  style: const TextStyle(
                                    color: Color(0xFF8B5E5A),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₹${item.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5E5A),
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No items found'),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Notes
            if (widget.sale.notes.isNotEmpty) ...[
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5E5A),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EBE6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.sale.notes,
                  style: const TextStyle(
                    color: Color(0xFF8B5E5A),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5E5A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '₹${widget.sale.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }
}
