import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class StartupLoadingGallery extends StatefulWidget {
  final List<Widget> images;

  const StartupLoadingGallery({
    super.key,
    required this.images,
  });

  @override
  State<StartupLoadingGallery> createState() => _StartupLoadingGalleryState();
}

class _StartupLoadingGalleryState extends State<StartupLoadingGallery>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              for (var index = 0; index < widget.images.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    right: index == widget.images.length - 1 ? 0 : 4,
                  ),
                  child: _buildAnimatedTile(index, widget.images[index]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedTile(int index, Widget image) {
    final progress =
        ((_controller.value - index * 0.1) / 0.22).clamp(0.0, 1.0).toDouble();

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset((1 - progress) * 32, 0),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: image,
        ),
      ),
    );
  }
}

class StartupLoadingPhoto extends StatelessWidget {
  final String? imagePath;
  final IconData placeholderIcon;

  const StartupLoadingPhoto({
    super.key,
    required this.imagePath,
    required this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim() ?? '';
    if (path.isEmpty) return _placeholder();

    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => _placeholder(),
        errorWidget: (context, url, error) => _placeholder(),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        placeholderIcon,
        size: 17,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}
