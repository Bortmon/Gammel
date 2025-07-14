import 'package:flutter/material.dart';

class ProductPriceInfo extends StatelessWidget {
  final String? priceString;
  final String? oldPriceString;
  final String? priceUnit;
  final String? ean;
  final bool isLoading;
  final String? discountLabel;
  final VoidCallback? onShowPromotionDetails;

  const ProductPriceInfo({
    super.key,
    required this.priceString,
    this.oldPriceString,
    this.priceUnit,
    this.ean,
    required this.isLoading,
    this.discountLabel,
    this.onShowPromotionDetails,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoading && priceString == null)
          Text("Laden...", style: txt.displaySmall?.copyWith(color: clr.onSurfaceVariant))
        else if (priceString != null)
          RichText(
            text: TextSpan(
              style: txt.displaySmall?.copyWith(color: clr.secondary, fontWeight: FontWeight.bold),
              children: [
                if (oldPriceString != null && oldPriceString!.isNotEmpty && oldPriceString != priceString)
                  TextSpan(
                    text: '€$oldPriceString ',
                    style: txt.headlineSmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: clr.onSurfaceVariant.withOpacity(0.6),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                TextSpan(text: '€$priceString'),
                if (priceUnit != null && priceUnit!.isNotEmpty)
                  TextSpan(
                      text: ' $priceUnit',
                      style: txt.titleLarge?.copyWith(color: clr.onSurfaceVariant, fontWeight: FontWeight.normal))
              ],
            ),
          )
        else
          Text('Prijs onbekend', style: txt.headlineSmall?.copyWith(fontStyle: FontStyle.italic, color: clr.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (ean != null && ean!.isNotEmpty)
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.barcode_reader, size: 18, color: clr.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Flexible(child: Text(ean!, style: txt.bodyMedium?.copyWith(color: clr.onSurfaceVariant))),
                  ],
                ),
              ),
            if (discountLabel != null && discountLabel!.isNotEmpty)
              _buildDiscountChip(context, txt, clr),
          ],
        ),
      ],
    );
  }

  Widget _buildDiscountChip(BuildContext context, TextTheme txt, ColorScheme clr) {
    final bool isTappable = onShowPromotionDetails != null;
    return Tooltip(
      message: isTappable ? "Bekijk actie details" : "",
      child: Material(
        color: clr.secondaryContainer,
        borderRadius: BorderRadius.circular(20.0),
        child: InkWell(
          onTap: isTappable ? onShowPromotionDetails : null,
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  discountLabel!,
                  style: txt.labelLarge?.copyWith(color: clr.onSecondaryContainer, fontWeight: FontWeight.bold),
                ),
                if (isTappable) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: clr.onSecondaryContainer,
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}