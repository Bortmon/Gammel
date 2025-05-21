import 'package:flutter/material.dart';
import '../core/product_details_data.dart'; 

class ProductPriceInfo extends StatelessWidget {
  final String? priceString;
  final String? oldPriceString;
  final String? priceUnit;
  final String? ean;
  final bool isLoading;
  final String? discountLabel; 
  final OrderabilityStatus orderStatus; 
  final VoidCallback? onShowPromotionDetails; 

  const ProductPriceInfo({
    super.key,
    required this.priceString,
    this.oldPriceString,
    this.priceUnit,
    this.ean,
    required this.isLoading,
    this.discountLabel,
    required this.orderStatus,
    this.onShowPromotionDetails,
  });

  Widget _buildOrderStatusChipWidget(OrderabilityStatus status, TextTheme textTheme, ColorScheme colorScheme) {
    IconData iconData;
    Color chipColor;
    Color contentColor;
    String label;

    switch (status) {
      case OrderabilityStatus.onlineAndCC:
        iconData = Icons.local_shipping_outlined;
        chipColor = colorScheme.primaryContainer.withAlpha((0.1 * 255).round()); 
        contentColor = colorScheme.onPrimaryContainer;
        label = "Online & Click/Collect";
        break;
      case OrderabilityStatus.clickAndCollectOnly:
        iconData = Icons.store_mall_directory_outlined;
        chipColor = colorScheme.tertiaryContainer.withAlpha((0.1 * 255).round());
        contentColor = colorScheme.onTertiaryContainer;
        label = "Alleen Click & Collect";
        break;
      case OrderabilityStatus.outOfAssortment:
        iconData = Icons.highlight_off_outlined;
        chipColor = colorScheme.errorContainer.withAlpha((0.1 * 255).round());
        contentColor = colorScheme.onErrorContainer;
        label = "Uit assortiment";
        break;
      case OrderabilityStatus.unknown:
      default:
        iconData = Icons.help_outline;
        chipColor = colorScheme.surfaceVariant.withAlpha((0.1 * 255).round());
        contentColor = colorScheme.onSurfaceVariant;
        label = "Status onbekend"; 
        break;
    }

    return Chip(
      avatar: Icon(iconData, size: 16, color: contentColor), 
      label: Text(label, style: textTheme.labelSmall?.copyWith(color: contentColor, fontWeight: FontWeight.w900)), 
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }


  @override
  Widget build(BuildContext context) {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;
    final bool isDiscountTappable = onShowPromotionDetails != null && discountLabel != null;


    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Prijs", style: txt.labelLarge?.copyWith(color: clr.onSurfaceVariant)),
              if (!isLoading && orderStatus != OrderabilityStatus.unknown)
                 _buildOrderStatusChipWidget(orderStatus, txt, clr),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading && priceString == null)
                      Text("Laden...", style: txt.headlineMedium?.copyWith(color: clr.onSurfaceVariant))
                    else if (priceString != null)
                      RichText(
                        text: TextSpan(
                          children: [
                            if (oldPriceString != null && oldPriceString!.isNotEmpty && oldPriceString != priceString)
                              TextSpan(
                                text: '€$oldPriceString ',
                                style: txt.titleMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: clr.onSurfaceVariant.withAlpha(180),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            TextSpan(
                              text: '€$priceString',
                              style: txt.headlineMedium?.copyWith(color: clr.secondary, fontWeight: FontWeight.bold),
                            ),
                            if (priceUnit != null && priceUnit!.isNotEmpty)
                              TextSpan(
                                text: ' $priceUnit',
                                style: txt.bodyMedium?.copyWith(color: clr.onSurfaceVariant)
                              )
                          ],
                        ),
                      )
                    else
                      Text('Prijs onbekend', style: txt.titleLarge?.copyWith(fontStyle: FontStyle.italic, color: clr.onSurfaceVariant)),
                  ],
                ),
              ),
              if (discountLabel != null && discountLabel!.isNotEmpty)
                Tooltip(
                  message: isDiscountTappable ? "Bekijk actie details" : "",
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isDiscountTappable ? onShowPromotionDetails : null,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: clr.primary, 
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              discountLabel!,
                              style: txt.labelMedium?.copyWith(color: clr.onPrimary, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isDiscountTappable)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.info_outline,
                                  size: (txt.labelMedium?.fontSize ?? 14.0) + 2,
                                  color: clr.onPrimary.withAlpha((0.8 * 255).round()),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (ean != null && ean!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                children: [
                  Icon(Icons.barcode_reader, size: 16, color: clr.onSurfaceVariant.withAlpha(150)),
                  const SizedBox(width: 6),
                  Text("EAN: $ean", style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}