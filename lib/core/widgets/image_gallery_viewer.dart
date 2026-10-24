import 'package:account_app/core/widgets/urdu_aware_text.dart';
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
  final String heroTagPrefix;
  final EdgeInsets? padding;

  const ImageGalleryViewer({
    super.key,
    required this.imagePaths,
    this.onRemove,
    this.isReadOnly = false,
    this.height = 200.0,
    this.isVerticalGrid = false,
    this.crossAxisCount = 3,
    this.heroTagPrefix = 'img',
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 16);

    if (isVerticalGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: effectivePadding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: imagePaths.length,
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
        padding: effectivePadding,
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return _imageItem(context, index, isGrid: false);
        },
      ),
    );
  }

  Widget _imageItem(BuildContext context, int index, {required bool isGrid}) {
    final path = imagePaths[index];

    return GestureDetector(
      onTap: () => _openGallery(context, index),
      child: Hero(
        tag: '${heroTagPrefix}_$index',
        child: Container(
          margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImage(path, isGrid),
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
                      child: Icon(
                        PhosphorIcons.x(),
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String path, bool isGrid) {
    final bool isNetwork = path.startsWith('http');

    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: isGrid ? BoxFit.cover : BoxFit.fitHeight,
        width: isGrid ? double.infinity : null,
        height: isGrid ? double.infinity : null,
        placeholder: (context, url) => Container(
          width: isGrid ? double.infinity : 100,
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: isGrid ? double.infinity : 100,
          color: Colors.grey[200],
          child: Icon(
            PhosphorIcons.imageBroken(),
            color: Colors.grey,
          ),
        ),
      );
    }

    // Local file
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: isGrid ? BoxFit.cover : BoxFit.fitHeight,
        width: isGrid ? double.infinity : null,
        height: isGrid ? double.infinity : null,
        errorBuilder: (_, __, ___) => _buildErrorContainer(isGrid),
      );
    }

    return _buildErrorContainer(isGrid);
  }

  Widget _buildErrorContainer(bool isGrid) {
    return Container(
      width: isGrid ? double.infinity : 100,
      color: Colors.grey[200],
      child: Icon(
        PhosphorIcons.imageBroken(),
        color: Colors.grey,
      ),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _SimpleGalleryDialog(
        imagePaths: imagePaths,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _SimpleGalleryDialog extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const _SimpleGalleryDialog({
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<_SimpleGalleryDialog> createState() => _SimpleGalleryDialogState();
}

class _SimpleGalleryDialogState extends State<_SimpleGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final path = widget.imagePaths[index];
                final bool isNetwork = path.startsWith('http');
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isNetwork
                        ? CachedNetworkImage(
                            imageUrl: path,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          )
                        : Image.file(
                            File(path),
                            fit: BoxFit.contain,
                          ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.imagePaths.length > 1)
            Positioned(
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: UrduAwareText(
                  "${_currentIndex + 1} / ${widget.imagePaths.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
