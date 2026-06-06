// file_utils.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

class FileUtils {
  static final ImagePicker _imagePicker = ImagePicker();

  // Get application documents directory
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  // Get temporary directory
  static Future<Directory> getTemporaryDirectory() async {
    return await getTemporaryDirectory();
  }

  // Check storage permission
  static Future<bool> hasStoragePermission() async {
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final result = await Permission.storage.request();
    return result.isGranted;
  }

  // Check camera permission
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  // Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    if (!await hasStoragePermission()) return null;

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  // Take photo with camera
  static Future<File?> takePhotoWithCamera() async {
    if (!await hasCameraPermission()) return null;

    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (photo != null) {
      return File(photo.path);
    }
    return null;
  }

  // Save file to documents directory
  static Future<File> saveFileToDocuments(
    Uint8List data,
    String fileName,
  ) async {
    final directory = await getAppDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(data);
    return file;
  }

  // Read file from documents directory
  static Future<Uint8List?> readFileFromDocuments(String fileName) async {
    try {
      final directory = await getAppDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Delete file from documents directory
  static Future<bool> deleteFileFromDocuments(String fileName) async {
    try {
      final directory = await getAppDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if file exists
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // Get file size
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Get file extension
  static String getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  // Get file name without extension
  static String getFileNameWithoutExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('.')
        : fileName;
  }

  // Is image file
  static bool isImageFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  // Is document file
  static bool isDocumentFile(String fileName) {
    final ext = getFileExtension(fileName);
    return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'].contains(ext);
  }

  // Create directory if not exists
  static Future<Directory> createDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // List files in directory
  static Future<List<File>> listFilesInDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        final files = await directory
            .list()
            .where((entity) => entity is File)
            .toList();
        return files.cast<File>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Copy file
  static Future<bool> copyFile(
    String sourcePath,
    String destinationPath,
  ) async {
    try {
      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);

      if (await sourceFile.exists()) {
        await sourceFile.copy(destinationPath);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Move file
  static Future<bool> moveFile(
    String sourcePath,
    String destinationPath,
  ) async {
    try {
      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);

      if (await sourceFile.exists()) {
        await sourceFile.rename(destinationPath);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get file MIME type
  static String getFileMimeType(String fileName) {
    final ext = getFileExtension(fileName);

    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
    };

    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  // Generate unique file name
  static String generateUniqueFileName(String originalName) {
    final ext = getFileExtension(originalName);
    final name = getFileNameWithoutExtension(originalName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return ext.isNotEmpty ? '$name-$timestamp.$ext' : '$name-$timestamp';
  }

  // Compress image file
  static Future<File?> compressImageFile(
    File imageFile, {
    int quality = 80,
  }) async {
    try {
      // Implementation for image compression
      // This would use flutter_image_compress package
      return imageFile; // Placeholder
    } catch (e) {
      return null;
    }
  }
/*
  // Get available storage space
  static Future<int> getAvailableStorageSpace() async {
    try {
      final directory = await getTemporaryDirectory();
      final stat = await directory.stat();
      return stat.availableSpace;
    } catch (e) {
      return 0;
    }
  }
*/
  // Clean up temporary files
  static Future<void> cleanupTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = await listFilesInDirectory(tempDir.path);

      final now = DateTime.now();
      for (final file in files) {
        final stat = await file.stat();
        final age = now.difference(stat.modified);

        // Delete files older than 7 days
        if (age.inDays > 7) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }
}
