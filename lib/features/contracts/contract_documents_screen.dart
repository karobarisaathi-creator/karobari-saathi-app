import 'dart:typed_data';

import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/services/contract_document_service.dart';
import 'package:flutter/material.dart';

class ContractDocumentsScreen extends StatefulWidget {
  final String contractTitle;
  final List<ContractDocument> documents;
  final bool isUrdu;

  const ContractDocumentsScreen({
    super.key,
    required this.contractTitle,
    required this.documents,
    required this.isUrdu,
  });

  @override
  State<ContractDocumentsScreen> createState() =>
      _ContractDocumentsScreenState();
}

class _ContractDocumentsScreenState extends State<ContractDocumentsScreen> {
  final ContractDocumentService _documentService = ContractDocumentService();
  late final Map<String, Future<Uint8List>> _imageLoads;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _imageLoads = {};
  }

  Future<Uint8List> _loadImage(ContractDocument document) =>
      _imageLoads.putIfAbsent(
        document.id,
        () => _documentService.loadImage(document),
      );

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(isUrdu ? Icons.arrow_forward : Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(widget.contractTitle),
          actions: [
            if (widget.documents.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${_currentPage + 1}/${widget.documents.length}'),
                ),
              ),
          ],
        ),
        body: PageView.builder(
          itemCount: widget.documents.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
          itemBuilder: (context, index) {
            final document = widget.documents[index];
            return Column(
              children: [
                Expanded(
                  child: FutureBuilder<Uint8List>(
                    future: _loadImage(document),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isUrdu
                                  ? 'تصویر لوڈ نہیں ہو سکی: ${snapshot.error}'
                                  : 'Could not load image: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5,
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    document.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
