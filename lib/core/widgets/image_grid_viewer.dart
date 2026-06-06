import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageGridViewer extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int)? onRemove;
  final bool isReadOnly;

  const ImageGridViewer({
    Key? key,
    required this.imagePaths,
    this.onRemove,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int count = imagePaths.length;
    if (count == 0) return const SizedBox.shrink();

    return _buildGrid(context, count);
  }

  Widget _buildGrid(BuildContext context, int count) {
    if (count == 1) {
      return AspectRatio(
        aspectRatio: 1.8,
        child: _imageItem(context, 0),
      );
    } else if (count == 2) {
      return AspectRatio(
        aspectRatio: 1.8,
        child: Row(
          children: [
            Expanded(child: _imageItem(context, 0)),
            const SizedBox(width: 4),
            Expanded(child: _imageItem(context, 1)),
          ],
        ),
      );
    } else if (count == 3) {
      return AspectRatio(
        aspectRatio: 1.5,
        child: Row(
          children: [
            Expanded(child: _imageItem(context, 0)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _imageItem(context, 1)),
                  const SizedBox(height: 4),
                  Expanded(child: _imageItem(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _imageItem(context, 0)),
                  const SizedBox(width: 4),
                  Expanded(child: _imageItem(context, 1)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _imageItem(context, 2)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _imageItem(context, 3),
                        if (count > 4)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Text(
                                '+${count - 4}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _imageItem(BuildContext context, int index) {
    final path = imagePaths[index];
    final bool isNetwork = path.startsWith('http');

    return GestureDetector(
      onTap: () => _openGallery(context, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          isNetwork
              ? CachedNetworkImage(
                  imageUrl: path,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
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
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
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
