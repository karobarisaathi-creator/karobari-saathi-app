import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/dispute_model.dart';

class ArtisanProService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 1. Audit Service
  // ====================
  Future<void> logAction({
    required String action,
    required String userId,
    required String workOrderId,
    Map<String, dynamic>? details,
  }) async {
    final deviceInfo = DeviceInfoPlugin();
    String? model;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = androidInfo.model;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.model;
    }

    await _firestore.collection('audit_logs').add({
      'action': action,
      'userId': userId,
      'workOrderId': workOrderId,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
      'deviceModel': model,
    });
  }

  // ============================================================
  // 2. Invoice Service
  // ====================
  Future<String> generateInvoice(ArtisanWorkOrder order) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Invoice #: ${order.id}'),
                pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(order.createdAt)}'),
                pw.Divider(),
                pw.Text('Artisan ID: ${order.artisanId}'),
                pw.Text('Customer: ${order.customerName}'),
                pw.Text('Phone: ${order.customerPhone}'),
                pw.Divider(),
                pw.Text('Work Description: ${order.workDescription}'),
                pw.SizedBox(height: 20),
                pw.Text('Amount: Rs. ${order.amount?.toStringAsFixed(0)}'),
                pw.Text('Status: ${order.status.toUpperCase()}'),
                pw.Divider(),
                pw.Text('Terms & Conditions:'),
                pw.Text('1. Payment should be made as per agreed terms.'),
                pw.Text('2. 30 days warranty on service provided.'),
                pw.Text('3. Digital signature verified by Karobari Saathi.'),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${order.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  // ============================================================
  // 3. Dispute Service
  // ====================
  Future<void> submitDispute(Dispute dispute) async {
    await _firestore.collection('disputes').doc(dispute.id).set(dispute.toMap());
    
    // Update Work Order with Dispute Status
    await _firestore.collectionGroup('work_orders')
      .where('id', isEqualTo: dispute.workOrderId)
      .get()
      .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'disputeStatus': 'open'});
        }
      });
  }

  // ============================================================
  // 4. Escrow Service
  // ====================
  Future<void> holdPayment({
    required String workOrderId,
    required double amount,
    required String customerId,
  }) async {
    await _firestore.collection('escrow').doc(workOrderId).set({
      'workOrderId': workOrderId,
      'amount': amount,
      'customerId': customerId,
      'status': 'held',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> releasePayment(String workOrderId) async {
    await _firestore.collection('escrow').doc(workOrderId).update({
      'status': 'released',
      'releasedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // 5. Privacy Service
  // ====================
  Future<void> requestDataDeletion(String userId) async {
    await _firestore.collection('data_deletion_requests').add({
      'userId': userId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
