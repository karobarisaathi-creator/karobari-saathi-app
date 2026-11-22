import 'dart:typed_data';

import 'package:account_app/core/models/contract_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ContractDocumentService {
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024;
  static const int maxDocumentsPerContract = 10;
  static const Uuid _uuid = Uuid();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ContractDocumentService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<ContractDocument> uploadImage({
    required String contractId,
    required XFile image,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before attaching contract documents.');
    }
    if (contractId.trim().isEmpty) {
      throw ArgumentError.value(
          contractId, 'contractId', 'Contract ID is required.');
    }

    final extension = image.name.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw FormatException(
          'Only JPEG, PNG, and WebP contract images are supported.'),
    };
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxDocumentSizeBytes) {
      throw FormatException(
          'Contract images must be between 1 byte and 10 MB.');
    }

    final documentId = _uuid.v4();
    final path =
        'users/${user.uid}/contracts/${Uri.encodeComponent(contractId)}/documents/$documentId.$extension';
    await _storage.ref(path).putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {'contractId': contractId},
          ),
        );

    return ContractDocument(
      id: documentId,
      ownerId: user.uid,
      storagePath: path,
      fileName: image.name,
      contentType: contentType,
      sizeBytes: bytes.length,
      uploadedAt: DateTime.now(),
    );
  }

  Future<Uint8List> loadImage(ContractDocument document) async {
    _requireOwnerPath(document);
    final bytes =
        await _storage.ref(document.storagePath).getData(maxDocumentSizeBytes);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Contract image is empty or unavailable.');
    }
    return bytes;
  }

  Future<String> getDownloadUrl(ContractDocument document) {
    _requireOwnerPath(document);
    return _storage.ref(document.storagePath).getDownloadURL();
  }

  Future<void> deleteDocument(ContractDocument document) async {
    _requireOwnerPath(document);
    await _storage.ref(document.storagePath).delete();
  }

  void _requireOwnerPath(ContractDocument document) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to access contract documents.');
    }
    if (document.ownerId != user.uid ||
        !document.storagePath.startsWith('users/${user.uid}/contracts/')) {
      throw StateError('This contract document does not belong to this user.');
    }
  }
}
