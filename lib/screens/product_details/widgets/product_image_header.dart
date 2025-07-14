import 'package:flutter/material.dart';
import '../core/product_details_data.dart'; 
import 'product_gallery_view.dart'; 

class ProductPrimaryInfoCard extends StatelessWidget {
  final String displayTitle;
  final String displayArticleCode;
  final String? displayEan;
  final String? detailImageUrl;
  final List<String> galleryImageUrls;
  final bool isLoadingDetails;
  final String? priceString;
  final OrderabilityStatus orderStatus;

  const ProductPrimaryInfoCard({
    super.key,
    required this.displayTitle,
    required this.displayArticleCode,
    this.displayEan,
    this.detailImageUrl,
    required this.galleryImageUrls,
    required this.isLoadingDetails,
    this.priceString,
    required this.orderStatus,
  });

  void _showImageGalleryDialog(BuildContext context) {
    if (galleryImageUrls.isEmpty && detailImageUrl == null) return;

    final List<String> imagesToShow = galleryImageUrls.isNotEmpty
        ? galleryImageUrls
        : (detailImageUrl != null ? [detailImageUrl!] : []);
        
    if (imagesToShow.isEmpty) return;

    int initialIndex = 0;
    if (detailImageUrl != null && imagesToShow.contains(detailImageUrl)) {
      initialIndex = imagesToShow.indexOf(detailImageUrl!);
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
            initialIndex: initialIndex,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clr = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: clr.outline.withAlpha((0.2 * 255).round())), 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(context),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(context, clr),
              const SizedBox(width: 16),
              _buildPriceAndDetails(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final clr = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            displayTitle,
            style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        if (displayArticleCode != "Laden..." && displayArticleCode != "Code?")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: clr.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Art: $displayArticleCode",
              style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _buildProductImage(BuildContext context, ColorScheme clr) {
    final heroTag =
        detailImageUrl ?? galleryImageUrls.firstOrNull ?? 'product_image_hero';

    return SizedBox(
      width: 96,
      height: 96,
      child: GestureDetector(
        onTap: () => _showImageGalleryDialog(context),
        child: Hero(
          tag: heroTag,
          child: Container(
            decoration: BoxDecoration(
              color: clr.surface,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: isLoadingDetails && detailImageUrl == null
                  ? Center(child: CircularProgressIndicator(color: clr.primary))
                  : (detailImageUrl != null
                      ? Image.network(
                          detailImageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, p) => p == null
                              ? child
                              : Center(
                                  child: CircularProgressIndicator(
                                  value: p.expectedTotalBytes != null
                                      ? p.cumulativeBytesLoaded /
                                          p.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2.0,
                                  color: clr.primary,
                                )),
                          errorBuilder: (ctx, err, st) => Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 40,
                                  color: clr.onSurfaceVariant.withAlpha((0.4 * 255).round()))), 
                        )
                      : Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 40,
                              color: clr.onSurfaceVariant.withAlpha((0.4 * 255).round())))), 
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceAndDetails(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final clr = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (isLoadingDetails && priceString == null)
            Text("Prijs laden...",
                style:
                    txt.headlineMedium?.copyWith(color: clr.onSurfaceVariant))
          else if (priceString != null)
            Text(
              '€$priceString',
              style: txt.headlineMedium
                  ?.copyWith(color: clr.secondary, fontWeight: FontWeight.bold),
            )
          else
            Text('Prijs onbekend',
                style: txt.titleLarge?.copyWith(
                    fontStyle: FontStyle.italic, color: clr.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (displayEan != null && displayEan!.isNotEmpty)
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 16, color: clr.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(displayEan!,
                        style: txt.bodyMedium
                            ?.copyWith(color: clr.onSurfaceVariant))),
              ],
            ),
          const SizedBox(height: 8),
          if (!isLoadingDetails && orderStatus != OrderabilityStatus.unknown)
            Chip(
              avatar: Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: clr.onPrimary,
              ),
              label: Text(
                orderStatus == OrderabilityStatus.onlineAndCC
                    ? "Online & Click/Collect"
                    : orderStatus == OrderabilityStatus.clickAndCollectOnly
                        ? "Alleen Click & Collect"
                        : orderStatus == OrderabilityStatus.outOfAssortment
                            ? "Uit assortiment"
                            : "Status onbekend",
                style: txt.labelMedium
                    ?.copyWith(color: clr.onPrimary, fontWeight: FontWeight.bold),
              ),
              backgroundColor: clr.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}