import 'dart:io';
import 'package:image/image.dart' as img_lib;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class ImageUtils {
  /// Compresses an image to reduce file size and resolution.
  /// This helps in saving storage costs and bandwidth.
  static Future<File> compressImage(File file, {int quality = 70, int maxWidth = 1024}) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img_lib.decodeImage(bytes);
      
      if (image == null) return file;

      // Resize if image is too wide
      img_lib.Image resizedImage = image;
      if (image.width > maxWidth) {
        resizedImage = img_lib.copyResize(image, width: maxWidth);
      }

      // Encode to JPG with specified quality
      final compressedBytes = img_lib.encodeJpg(resizedImage, quality: quality);
      
      final tempDir = await getTemporaryDirectory();
      final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      return await compressedFile.writeAsBytes(compressedBytes);
    } catch (e) {
      debugPrint("Image compression error: $e");
      return file; // Fallback to original
    }
  }

  /// Strips metadata and compresses image.
  static Future<File> getCleanCompressedImage(File file) async {
    return await compressImage(file, quality: 75, maxWidth: 1200);
  }
}
