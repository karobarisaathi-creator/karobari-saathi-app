import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';

class ImageSelectorField extends StatefulWidget {
  final List<File> selectedFiles;
  final List<String> remoteUrls;
  final Function(List<File>) onFilesChanged;
  final Function(int)? onRemoteRemoved;
  final int maxTotal;
  final String? label;
  final bool isProfile;
  final bool isFullWidth;
  final double? customSize;
  final double aspectRatio;

  const ImageSelectorField({
    super.key,
    required this.selectedFiles,
    this.remoteUrls = const [],
    required this.onFilesChanged,
    this.onRemoteRemoved,
    this.maxTotal = 3,
    this.label,
    this.isProfile = false,
    this.isFullWidth = false,
    this.customSize,
    this.aspectRatio = 4 / 3,
  });

  @override
  State<ImageSelectorField> createState() => _ImageSelectorFieldState();
}

class _ImageSelectorFieldState extends State<ImageSelectorField> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null && mounted) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: widget.isProfile 
              ? const CropAspectRatio(ratioX: 1, ratioY: 1)
              : widget.isFullWidth 
                  ? CropAspectRatio(ratioX: widget.aspectRatio, ratioY: 1)
                  : const CropAspectRatio(ratioX: 4, ratioY: 3),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isUrdu ? 'تصویر کاٹیں' : 'Crop Image',
              toolbarColor: AppTheme.darkColor,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: widget.isProfile || widget.isFullWidth,
            ),
          ],
        );

        if (croppedFile != null) {
          final compressedFile = await ImageUtils.compressImage(File(croppedFile.path));
          List<File> updatedList = List.from(widget.selectedFiles);
          if (widget.isProfile || (widget.isFullWidth && widget.maxTotal == 1)) {
            updatedList = [compressedFile]; 
          } else {
            updatedList.add(compressedFile);
          }
          widget.onFilesChanged(updatedList);
        }
      }
    } catch (e) {
      debugPrint("Error picking/cropping image: $e");
    }
  }

  void _removeFile(int index) {
    List<File> updatedList = List.from(widget.selectedFiles);
    updatedList.removeAt(index);
    widget.onFilesChanged(updatedList);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final size = widget.customSize ?? (widget.isProfile ? 110.0 : 70.0);

    if (widget.isProfile) {
      return Center(child: _buildProfilePicker(size, isUrdu, fontFamily));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!, 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: fontFamily, color: AppTheme.darkColor)
          ),
          const SizedBox(height: 10),
        ],
        if (widget.isFullWidth && widget.maxTotal == 1)
          _buildFullWidthPicker(isUrdu, fontFamily)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Remote Images
              ...widget.remoteUrls.asMap().entries.map((entry) => _buildImageItem(
                size: size,
                image: CachedNetworkImage(
                  imageUrl: entry.value,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                onRemove: () => widget.onRemoteRemoved?.call(entry.key),
              )),

              // Local Files
              ...widget.selectedFiles.asMap().entries.map((entry) => _buildImageItem(
                size: size,
                image: Image.file(entry.value, fit: BoxFit.cover),
                onRemove: () => _removeFile(entry.key),
              )),

              // Add Button
              if (widget.selectedFiles.length + widget.remoteUrls.length < widget.maxTotal)
                _buildAddButton(size, isUrdu, fontFamily),
            ],
          ),
      ],
    );
  }

  Widget _buildFullWidthPicker(bool isUrdu, String fontFamily) {
    Widget? displayImage;
    bool hasImage = false;

    if (widget.selectedFiles.isNotEmpty) {
      displayImage = Image.file(widget.selectedFiles.first, fit: BoxFit.cover);
      hasImage = true;
    } else if (widget.remoteUrls.isNotEmpty) {
      displayImage = CachedNetworkImage(
        imageUrl: widget.remoteUrls.first,
        fit: BoxFit.cover,
      );
      hasImage = true;
    }

    return GestureDetector(
      onTap: _pickImage,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: displayImage,
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIcons.cameraPlus(), size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    Text(
                      isUrdu ? 'تصویر منتخب کریں' : 'Select Image', 
                      style: TextStyle(color: Colors.grey[500], fontFamily: fontFamily, fontSize: 13)
                    ),
                  ],
                ),
              if (hasImage)
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.selectedFiles.isNotEmpty) _removeFile(0);
                      else widget.onRemoteRemoved?.call(0);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageItem({required double size, required Widget image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: image,
          ),
        ),
        Positioned(
          top: 2, right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(double size, bool isUrdu, String fontFamily) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.camera(), color: AppTheme.themeColor, size: size * 0.35),
            const SizedBox(height: 4),
            Text(
              isUrdu ? 'شامل کریں' : 'Add', 
              style: TextStyle(fontSize: 10, fontFamily: fontFamily, color: Colors.grey[600])
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicker(double size, bool isUrdu, String fontFamily) {
    Widget? displayImage;
    bool hasImage = false;

    if (widget.selectedFiles.isNotEmpty) {
      displayImage = Image.file(widget.selectedFiles.first, fit: BoxFit.cover);
      hasImage = true;
    } else if (widget.remoteUrls.isNotEmpty) {
      displayImage = CachedNetworkImage(
        imageUrl: widget.remoteUrls.first,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(PhosphorIcons.user(), size: size * 0.4, color: Colors.grey[400]),
      );
      hasImage = true;
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.themeColor.withOpacity(0.2), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasImage 
                ? displayImage 
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIcons.camera(), size: size * 0.3, color: Colors.grey[400]),
                      const SizedBox(height: 4),
                      Text(isUrdu ? 'تصویر' : 'Photo', style: TextStyle(fontSize: 12, color: Colors.grey[400], fontFamily: fontFamily)),
                    ],
                  ),
            ),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.themeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(PhosphorIcons.pencilSimple(), color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
