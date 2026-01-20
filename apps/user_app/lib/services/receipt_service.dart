// ignore_for_file: uri_does_not_exist, undefined_identifier
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils/time_utils.dart';

class ReceiptService {
  Future<Uint8List> buildReceiptPdf(Map<String, dynamic> order) async {
    final doc = pw.Document();

    final createdAt = order['created_at'] as String?;
    final createdPretty = TimeUtils.formatDateTime(createdAt);
    final status = (order['status'] as String? ?? 'pending').toUpperCase();
    final total = (order['total_amount'] as num? ?? 0).toDouble();
    final orderId = (order['id'] ?? '').toString();
    final itemsJson = order['items_json'] as dynamic;
    final List items = itemsJson is String ? jsonDecode(itemsJson) : (itemsJson ?? []);

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Saral Events - Payment Receipt', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Text('Order ID: $orderId'),
          pw.Text('Date: $createdPretty'),
          pw.SizedBox(height: 12),
          pw.Text('Status: $status'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Item', 'Category', 'Price'],
            data: [
              for (final it in items)
                [
                  (it['title'] ?? it['item_id'] ?? '').toString(),
                  (it['category'] ?? '').toString(),
                  '₹${(((it['price'] as num?) ?? 0).toDouble()).toStringAsFixed(2)}',
                ]
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Total: ₹${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Thank you for choosing Saral Events!'),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> shareReceipt(BuildContext context, Map<String, dynamic> order) async {
    try {
      final pdfBytes = await buildReceiptPdf(order);
      await Printing.sharePdf(bytes: pdfBytes, filename: 'receipt_${order['id']}.pdf');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing receipt: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to share receipt')));
    }
  }
}


