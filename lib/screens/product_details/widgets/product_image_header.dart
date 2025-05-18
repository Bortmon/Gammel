import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../core/product_details_data.dart';

class ProductImageHeader extends StatelessWidget {
  final Product product;
  final String displayTitle;
  final String displayArticleCode;
  final String? displayEan;
  final String? detailImageUrl;
  final String? detailPriceString;
  final String? detailOldPriceString;
  final String? detailPriceUnit;
  final String? detailPricePerUnitString;
  final String? detailPricePerUnitLabel;
  final String? detailDiscountLabel;
  final String? detailPromotionDescription;
  final OrderabilityStatus orderStatus;
  final bool isLoadingDetails;
  final VoidCallback onShowPromotionDetails;

  const ProductImageHeader({
    super.key,
    required this.product,
    required this.displayTitle,
    required this.displayArticleCode,
    this.displayEan,
    required this.detailImageUrl,
    required this.detailPriceString,
    this.detailOldPriceString,
    this.detailPriceUnit,
    this.detailPricePerUnitString,
    this.detailPricePerUnitLabel,
    this.detailDiscountLabel,
    this.detailPromotionDescription,
    required this.orderStatus,
    required this.isLoadingDetails,
    required this.onShowPromotionDetails,
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

  Widget _buildPriceSection(TextTheme txt, ColorScheme clr, BuildContext context) {
    final bool isDiscountTappable = detailPromotionDescription != null && detailPromotionDescription!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoadingDetails && detailPriceString == null)
                Text("Prijs laden...", style: txt.headlineMedium?.copyWith(color: Colors.grey[600]))
              else if (detailPriceString != null)
                RichText(
                  text: TextSpan(
                    style: txt.headlineMedium?.copyWith(color: clr.onSurface, fontWeight: FontWeight.bold, fontSize: 28),
                    children: [
                      if (detailOldPriceString != null && detailOldPriceString != detailPriceString)
                        TextSpan(
                          text: '€$detailOldPriceString ',
                          style: TextStyle(
                            fontSize: txt.titleSmall?.fontSize ?? 14,
                            decoration: TextDecoration.lineThrough,
                            color: clr.onSurfaceVariant.withAlpha((0.7 * 255).round()),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      TextSpan(
                        text: '€$detailPriceString',
                        style: TextStyle(
                          color: clr.secondary, 
                        ),
                      ),
                      if (detailPriceUnit != null)
                        TextSpan(
                          text: ' $detailPriceUnit',
                          style: txt.bodyMedium?.copyWith(color: clr.onSurfaceVariant, fontWeight: FontWeight.normal, fontSize: 15)
                        )
                    ],
                  ),
                )
              else
                Text('Prijs onbekend', style: txt.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600])),

              if (detailPricePerUnitString != null && detailPricePerUnitString != detailPriceString)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '€$detailPricePerUnitString ${(detailPricePerUnitLabel ?? "p/eenheid").toLowerCase()}',
                    style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: clr.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        if (detailDiscountLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Tooltip(
              message: isDiscountTappable ? "Bekijk actie details" : "",
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDiscountTappable ? onShowPromotionDetails : null,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: clr.primary, 
                      borderRadius: BorderRadius.circular(8.0),
                       boxShadow:
                       [
                         BoxShadow(
                           color: Colors.black.withAlpha((0.08 * 255).round()),
                           blurRadius: 5,
                           offset: const Offset(0, 2),
                         )
                       ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:
                      [
                        Text(
                          detailDiscountLabel!,
                          style: txt.labelLarge?.copyWith(
                            color: clr.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isDiscountTappable)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Icon(
                              Icons.info_outline,
                              size: (txt.labelLarge?.fontSize ?? 16.0),
                              color: clr.onPrimary.withAlpha((0.8 * 255).round()),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
                width: 120,
                height: 120,
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
                    const SizedBox(height: 10),
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

          const SizedBox(height: 20),

          if (!isLoadingDetails)
            _buildOrderStatusChipWidget(orderStatus, txt, clr)
          else
            const SizedBox(height: 36),

          const SizedBox(height: 16),

          _buildPriceSection(txt, clr, context),
        ],
      ),
    );
  }
}