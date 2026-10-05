import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/image_utils.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'package:account_app/core/widgets/app_toast.dart';

import 'image_gallery_viewer.dart';

class ImageSelectorField extends StatefulWidget {
  final List<File> selectedFiles;
  final List<String> remoteUrls;
  final Function(List<File>) onFilesChanged;
  final Function(int)? onRemoteRemoved;
  final int maxTotal;
  final String? label;
  final bool isProfile;
  final bool isFullWidth;
  final bool isVertical;
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
    this.isVertical = false,
    this.customSize,
    this.aspectRatio = 4 / 3,
  });

  @override
  State<ImageSelectorField> createState() => _ImageSelectorFieldState();
}

class _ImageSelectorFieldState extends State<ImageSelectorField> {
  final _logger = LoggingService();
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickImage() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        final croppedFile = await _cropImage(image, isUrdu);
        if (croppedFile != null) {
          final compressedFile = await ImageUtils.compressImage(File(croppedFile.path));
          _updateFiles(compressedFile);
        }
      }
    } catch (e, stack) {
      _logger.error("Image pick error", e, stack);
      if (mounted) {
        AppToast.error(
          context,
          Provider.of<LanguageService>(context, listen: false).isUrdu
              ? 'تصویر منتخب کرنے میں ناکامی'
              : 'Failed to pick image',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<CroppedFile?> _cropImage(XFile image, bool isUrdu) async {
    try {
      return await ImageCropper().cropImage(
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
    } catch (e, stack) {
      _logger.error("Image crop error", e, stack);
      return null;
    }
  }

  void _updateFiles(File compressedFile) {
    List<File> updatedList = List.from(widget.selectedFiles);
    
    if (widget.isProfile || (widget.isFullWidth && widget.maxTotal == 1)) {
      updatedList = [compressedFile];
    } else {
      updatedList.add(compressedFile);
    }
    
    widget.onFilesChanged(updatedList);
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.isFullWidth && widget.maxTotal == 1)
          _buildFullWidthPicker(isUrdu, fontFamily)
        else if (widget.isVertical)
          _buildVerticalPicker(size, isUrdu, fontFamily)
        else
          _buildWrapPicker(size, isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildVerticalPicker(double size, bool isUrdu, String fontFamily) {
    final allImages = [
      ...widget.remoteUrls,
      ...widget.selectedFiles.map((f) => f.path),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ImageGalleryViewer(
              imagePaths: allImages,
              onRemove: (index) {
                if (index < widget.remoteUrls.length) {
                  widget.onRemoteRemoved?.call(index);
                } else {
                  _removeFile(index - widget.remoteUrls.length);
                }
              },
              isReadOnly: false,
              isVerticalGrid: true,
              crossAxisCount: 1,
              padding: EdgeInsets.zero,
            ),
          ),
        if (allImages.length < widget.maxTotal)
          _buildAddButton(widget.isFullWidth ? double.infinity : size, isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildWrapPicker(double size, bool isUrdu, String fontFamily) {
    final allImages = [
      ...widget.remoteUrls,
      ...widget.selectedFiles.map((f) => f.path),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ImageGalleryViewer(
              imagePaths: allImages,
              onRemove: (index) {
                if (index < widget.remoteUrls.length) {
                  widget.onRemoteRemoved?.call(index);
                } else {
                  _removeFile(index - widget.remoteUrls.length);
                }
              },
              isReadOnly: false,
              isVerticalGrid: true,
              crossAxisCount: 3,
              padding: EdgeInsets.zero,
            ),
          ),
        if (allImages.length < widget.maxTotal)
          _buildAddButton(size, isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildFullWidthPicker(bool isUrdu, String fontFamily) {
    final allImages = [
      ...widget.remoteUrls,
      ...widget.selectedFiles.map((f) => f.path),
    ];

    if (allImages.isNotEmpty) {
      return ImageGalleryViewer(
        imagePaths: allImages,
        onRemove: (index) {
          if (index < widget.remoteUrls.length) {
            widget.onRemoteRemoved?.call(index);
          } else {
            _removeFile(index - widget.remoteUrls.length);
          }
        },
        isReadOnly: false,
        isVerticalGrid: true,
        crossAxisCount: 1,
        padding: EdgeInsets.zero,
      );
    }

    return GestureDetector(
      onTap: _isPicking ? null : _pickImage,
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
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.cameraPlus(),
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isUrdu ? 'تصویر منتخب کریں' : 'Select Image',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: fontFamily,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (_isPicking)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(double size, bool isUrdu, String fontFamily) {
    return InkWell(
      onTap: _isPicking ? null : _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size == double.infinity ? 65 : size,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.camera(),
              color: AppTheme.themeColor,
              size: size == double.infinity ? 24 : size * 0.35,
            ),
            const SizedBox(height: 4),
            Text(
              isUrdu ? 'شامل کریں' : 'Add',
              style: TextStyle(
                fontSize: 10,
                fontFamily: fontFamily,
                color: Colors.grey[600],
              ),
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
      final url = widget.remoteUrls.first;
      displayImage = _buildRemoteImage(url, size);
      hasImage = true;
    }

    return GestureDetector(
      onTap: _isPicking ? null : _pickImage,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.themeColor.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasImage
                  ? displayImage
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIcons.camera(),
                          size: size * 0.3,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUrdu ? 'تصویر' : 'Photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.themeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                PhosphorIcons.pencilSimple(),
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          if (hasImage)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  if (widget.selectedFiles.isNotEmpty) {
                    _removeFile(0);
                  } else {
                    widget.onRemoteRemoved?.call(0);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          if (_isPicking)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteImage(String url, double size) {
    if (url.startsWith('assets/') && url.endsWith('.svg')) {
      return SvgPicture.asset(url, fit: BoxFit.cover);
    }
    
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Icon(
        PhosphorIcons.user(),
        size: size * 0.4,
        color: Colors.grey[400],
      ),
    );
  }
}
