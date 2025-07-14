// lib/widgets/product_main_image.dart

import 'package:flutter/material.dart';
import 'product_gallery_view.dart';

class ProductMainImage extends StatelessWidget {
  final String? imageUrl;
  final List<String> galleryImageUrls;
  final bool isLoading;

  const ProductMainImage({
    super.key,
    required this.imageUrl,
    required this.galleryImageUrls,
    required this.isLoading,
  });

  void _showImageGalleryDialog(BuildContext context) {
    if (galleryImageUrls.isEmpty && imageUrl == null) return;

    List<String> imagesToShow =
        galleryImageUrls.isNotEmpty ? galleryImageUrls : (imageUrl != null ? [imageUrl!] : []);
    if (imagesToShow.isEmpty) return;

    int initialImageIndex = 0;
    if (imageUrl != null && imagesToShow.contains(imageUrl)) {
      initialImageIndex = imagesToShow.indexOf(imageUrl!);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      useSafeArea: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: ProductGalleryDialogContent(
            imageUrls: imagesToShow,
            initialIndex: initialImageIndex,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme clr = Theme.of(context).colorScheme;
    final heroTag = imageUrl ?? galleryImageUrls.firstOrNull ?? 'product_image_hero';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: GestureDetector(
          onTap: () => _showImageGalleryDialog(context),
          child: Hero(
            tag: heroTag,
            child: Container(
              decoration: BoxDecoration(
                color: clr.surfaceContainer,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: clr.outline.withOpacity(0.2)),
              ),
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: clr.primary))
                  : (imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15.5),
                          child: Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, p) => (p == null)
                                ? child
                                : Center(
                                    child: CircularProgressIndicator(
                                    value: p.expectedTotalBytes != null
                                        ? p.cumulativeBytesLoaded / p.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2.0,
                                    color: clr.primary,
                                  )),
                            errorBuilder: (ctx, err, st) => Center(
                                child: Icon(Icons.broken_image_outlined,
                                    size: 50, color: clr.onSurfaceVariant.withOpacity(0.4))),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 50, color: clr.onSurfaceVariant.withOpacity(0.4)))),
            ),
          ),
        ),
      ),
    );
  }
}