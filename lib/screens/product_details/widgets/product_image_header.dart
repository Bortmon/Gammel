import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../core/product_details_data.dart';

class ProductImageHeader extends StatelessWidget {
  final Product product; // TERUGGEZET
  final String displayTitle;
  final String displayArticleCode;
  final String? displayEan;
  final String? detailImageUrl;
  final OrderabilityStatus orderStatus;
  final bool isLoadingDetails;

  const ProductImageHeader({
    super.key,
    required this.product, // TERUGGEZET
    required this.displayTitle,
    required this.displayArticleCode,
    this.displayEan,
    required this.detailImageUrl,
    required this.orderStatus,
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

  Widget _buildOrderStatusChipWidget(OrderabilityStatus status, TextTheme textTheme, ColorScheme colorScheme) {
    IconData iconData;
    Color chipColor;
    Color contentColor;
    String label;

    switch (status) {
      case OrderabilityStatus.onlineAndCC:
        iconData = Icons.local_shipping_outlined;
        chipColor = colorScheme.primaryContainer.withAlpha((0.6 * 255).round()); 
        contentColor = colorScheme.onPrimaryContainer;
        label = "Online & Click/Collect";
        break;
      case OrderabilityStatus.clickAndCollectOnly:
        iconData = Icons.store_mall_directory_outlined;
        chipColor = colorScheme.tertiaryContainer.withAlpha((0.6 * 255).round());
        contentColor = colorScheme.onTertiaryContainer;
        label = "Alleen Click & Collect";
        break;
      case OrderabilityStatus.outOfAssortment:
        iconData = Icons.highlight_off_outlined;
        chipColor = colorScheme.errorContainer.withAlpha((0.6 * 255).round());
        contentColor = colorScheme.onErrorContainer;
        label = "Uit assortiment";
        break;
      case OrderabilityStatus.unknown:
      default:
        iconData = Icons.help_outline;
        chipColor = colorScheme.surfaceVariant.withAlpha((0.6 * 255).round());
        contentColor = colorScheme.onSurfaceVariant;
        label = "Bestelstatus onbekend";
        break;
    }

    return Chip(
      avatar: Icon(iconData, size: 18, color: contentColor),
      label: Text(label, style: textTheme.bodyMedium?.copyWith(color: contentColor, fontWeight: FontWeight.w500)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
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
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: clr.outline.withAlpha((0.3 * 255).round()), width: 0.5)

                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11.5),
                  child: detailImageUrl != null
                      ? Image.network(
                          detailImageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, p) => (p == null)
                              ? child
                              : Container(alignment: Alignment.center, child: CircularProgressIndicator(value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null, strokeWidth: 2.0,)),
                          errorBuilder: (ctx, err, st) => Container(color: clr.surfaceContainerHighest.withAlpha(30), alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, size: 40, color: clr.onSurface.withAlpha(100))),
                        )
                      : Container(color: clr.surfaceContainerHighest.withAlpha(30), alignment: Alignment.center, child: Icon(Icons.image_not_supported_outlined, size: 40, color: clr.onSurface.withAlpha(100))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(displayTitle, style: txt.titleLarge?.copyWith(height: 1.3, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildCodeRow(Icons.inventory_2_outlined, 'Art:', displayArticleCode, txt, clr),
                    if (displayEan != null) 
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: _buildCodeRow(Icons.barcode_reader, 'EAN:', displayEan!, txt, clr),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isLoadingDetails)
            _buildOrderStatusChipWidget(orderStatus, txt, clr)
          else
            const SizedBox(height: 36), 
        ],
      ),
    );
  }
}