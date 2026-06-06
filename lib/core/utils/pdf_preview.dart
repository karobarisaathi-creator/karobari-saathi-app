// pdf_preview.dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final pw.Document pdfDocument;
  final String fileName;

  const PdfPreviewScreen({required this.pdfDocument, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Preview'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _sharePdf(context),
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _savePdf(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfDocument.save(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    // Implementation for sharing PDF
    // This would use share_plus package
    final bytes = await pdfDocument.save();
    // Share.file('Share PDF', '$fileName.pdf', bytes, 'application/pdf');
  }

  Future<void> _savePdf(BuildContext context) async {
    // Implementation for saving PDF to device
    // This would use path_provider and file picker
    final bytes = await pdfDocument.save();
    // Save file logic here
  }
}
