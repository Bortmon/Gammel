import 'package:flutter/material.dart';
import 'product_gallery_view.dart';

class ProductImageHeader extends StatelessWidget {
  final String displayTitle;
  final String displayArticleCode;
  final String? displayEan;
  final String? detailImageUrl;
  final List<String> galleryImageUrlsForNav; 
  final bool isLoadingDetails;

  const ProductImageHeader({
    super.key,
    required this.displayTitle,
    required this.displayArticleCode,
    this.displayEan,
    required this.detailImageUrl,
    required this.galleryImageUrlsForNav,
    required this.isLoadingDetails,
  });

  Widget _buildCodeRow(IconData icon, String label, String value, TextTheme txt, ColorScheme clr) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: txt.bodySmall?.color?.withAlpha((0.7 * 255).round())),
          const SizedBox(width: 6),
          Text(label, style: txt.bodyMedium?.copyWith(color: txt.bodySmall?.color?.withAlpha((0.9 * 255).round()), fontSize: 13)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
  
  void _showImageGalleryDialog(BuildContext context) {
    if (galleryImageUrlsForNav.isEmpty && detailImageUrl == null) return;
    
    List<String> imagesToShow = galleryImageUrlsForNav.isNotEmpty ? galleryImageUrlsForNav : (detailImageUrl != null ? [detailImageUrl!] : []);
    if (imagesToShow.isEmpty) return;

    int initialImageIndex = 0;
    if (detailImageUrl != null && imagesToShow.contains(detailImageUrl)) {
      initialImageIndex = imagesToShow.indexOf(detailImageUrl!);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.85 * 255).round()),
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
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showImageGalleryDialog(context),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: clr.outline.withAlpha((0.3 * 255).round()), width: 0.5)

                  ),
                  child: Hero( 
                    tag: detailImageUrl ?? galleryImageUrlsForNav.firstOrNull ?? 'product_image_hero',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11.5),
                      child: isLoadingDetails 
                        ? Center(child: CircularProgressIndicator(color: clr.primary, strokeWidth: 2.0))
                        : (detailImageUrl != null
                          ? Image.network(
                              detailImageUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, p) => (p == null)
                                  ? child
                                  : Container(alignment: Alignment.center, child: CircularProgressIndicator(value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null, strokeWidth: 2.0,)),
                              errorBuilder: (ctx, err, st) => Container(color: clr.surfaceContainerHighest.withAlpha(30), alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, size: 40, color: clr.onSurface.withAlpha(100))),
                            )
                          : Container(color: clr.surfaceContainerHighest.withAlpha(30), alignment: Alignment.center, child: Icon(Icons.image_not_supported_outlined, size: 40, color: clr.onSurface.withAlpha(100)))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (isLoadingDetails)
                      Container(height: txt.titleLarge?.fontSize, width: double.infinity, color: clr.surfaceVariant.withAlpha(100)) // Placeholder
                    else
                      Text(displayTitle, style: txt.titleLarge?.copyWith(height: 1.3, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                     if (isLoadingDetails)
                        Container(height: txt.bodyMedium?.fontSize, width: 100, color: clr.surfaceVariant.withAlpha(100)) // Placeholder
                     else
                        _buildCodeRow(Icons.inventory_2_outlined, 'Art:', displayArticleCode, txt, clr),
                    if (!isLoadingDetails && displayEan != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: _buildCodeRow(Icons.barcode_reader, 'EAN:', displayEan!, txt, clr),
                      )
                    else if (isLoadingDetails) // Placeholder voor EAN
                       Padding(
                         padding: const EdgeInsets.only(top: 2.0),
                         child: Container(height: txt.bodyMedium?.fontSize, width: 150, color: clr.surfaceVariant.withAlpha(100)),
                       ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}