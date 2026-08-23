import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ImageGalleryViewer extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int)? onRemove;
  final bool isReadOnly;
  final double height;
  final bool isVerticalGrid;
  final int crossAxisCount;

  const ImageGalleryViewer({
    super.key,
    required this.imagePaths,
    this.onRemove,
    this.isReadOnly = false,
    this.height = 200.0,
    this.isVerticalGrid = false,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    int count = imagePaths.length;
    if (count == 0) return const SizedBox.shrink();

    if (isVerticalGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return _imageItem(context, index, isGrid: true);
        },
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (context, index) {
          return _imageItem(context, index, isGrid: false);
        },
      ),
    );
  }

  Widget _imageItem(BuildContext context, int index, {required bool isGrid}) {
    final path = imagePaths[index];
    final bool isNetwork = path.startsWith('http');

    return GestureDetector(
      onTap: () => _openGallery(context, index),
      child: Container(
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isNetwork
                  ? CachedNetworkImage(
                      imageUrl: path,
                      fit: isGrid ? BoxFit.cover : BoxFit.fitHeight, // گرڈ میں کور، سلائیڈر میں فٹ ہائٹ
                      width: isGrid ? double.infinity : null, // سلائیڈر میں ڈائنامک چوڑائی
                      height: isGrid ? double.infinity : null,
                      placeholder: (context, url) => Container(
                        width: isGrid ? double.infinity : 100,
                        color: Colors.grey[200],
                        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: isGrid ? double.infinity : 100,
                        color: Colors.grey[200],
                        child: Icon(PhosphorIcons.imageBroken(), color: Colors.grey),
                      ),
                    )
                  : Image.file(
                      File(path),
                      fit: isGrid ? BoxFit.cover : BoxFit.fitHeight, // گرڈ میں کور، سلائیڈر میں فٹ ہائٹ
                      width: isGrid ? double.infinity : null, // سلائیڈر میں ڈائنامک چوڑائی
                      height: isGrid ? double.infinity : null,
                      errorBuilder: (_, __, ___) => Container(
                        width: isGrid ? double.infinity : 100,
                        color: Colors.grey[200],
                        child: Icon(PhosphorIcons.imageBroken(), color: Colors.grey),
                      ),
                    ),
            ),
            if (!isReadOnly && onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => onRemove!(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorIcons.x(), color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoViewGallery.builder(
            itemCount: imagePaths.length,
            builder: (context, index) {
              final path = imagePaths[index];
              final bool isNetwork = path.startsWith('http');
              return PhotoViewGalleryPageOptions(
                imageProvider: isNetwork 
                    ? CachedNetworkImageProvider(path) as ImageProvider
                    : FileImage(File(path)) as ImageProvider,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: "img_$index"),
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: initialIndex),
          ),
        ),
      ),
    );
  }
}
