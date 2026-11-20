import 'package:account_app/core/models/contract_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contract document metadata survives contract serialization', () {
    final uploadedAt = DateTime(2026, 11, 20, 8, 30);
    final contract = ContractModel(
      id: 'contract-1',
      partyId: 'party-1',
      partyName: 'Customer',
      title: 'Stamp paper',
      totalAmount: 120000,
      startDate: DateTime(2026, 11, 1),
      documents: [
        ContractDocument(
          id: 'document-1',
          ownerId: 'user-1',
          storagePath:
              'users/user-1/contracts/contract-1/documents/document-1.jpg',
          fileName: 'stamp.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1200,
          uploadedAt: uploadedAt,
        ),
      ],
      createdAt: uploadedAt,
      updatedAt: uploadedAt,
    );

    final restored = ContractModel.fromMap(contract.toMap());
    expect(restored.documents, hasLength(1));
    expect(restored.documents.single.ownerId, 'user-1');
    expect(restored.documents.single.storagePath, contains('contract-1'));
    expect(restored.documents.single.uploadedAt, uploadedAt);
  });

  test('contracts without a documents field remain compatible', () {
    final contract = ContractModel.fromMap({
      'id': 'legacy',
      'partyId': '',
      'partyName': '',
      'title': 'Legacy contract',
      'totalAmount': 100,
      'startDate': '2026-11-20T00:00:00.000',
      'createdAt': '2026-11-20T00:00:00.000',
      'updatedAt': '2026-11-20T00:00:00.000',
    });

    expect(contract.documents, isEmpty);
  });
}
