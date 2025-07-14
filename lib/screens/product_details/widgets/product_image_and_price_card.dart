import 'package:flutter/material.dart';
import '../core/product_details_data.dart';
import 'product_main_image.dart';
import 'product_price_info.dart';

class ProductImageAndPriceCard extends StatelessWidget {
  final ProductDetailsScrapeResult details;
  final bool isLoading;
  final VoidCallback? onShowPromotionDetails;

  const ProductImageAndPriceCard({
    super.key,
    required this.details,
    required this.isLoading,
    this.onShowPromotionDetails,
  });

  @override
  Widget build(BuildContext context) {
    final clr = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: clr.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductMainImage(
              imageUrl: details.imageUrl,
              galleryImageUrls: details.galleryImageUrls,
              isLoading: isLoading,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ProductPriceInfo(
                priceString: details.priceString,
                oldPriceString: details.oldPriceString,
                priceUnit: details.priceUnit,
                ean: details.scrapedEan,
                isLoading: isLoading,
                discountLabel: details.discountLabel,
                onShowPromotionDetails: onShowPromotionDetails,
              ),
            ),
          ],
        ),
      ),
    );
  }
}