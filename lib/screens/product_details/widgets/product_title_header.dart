import 'package:flutter/material.dart';
import '../core/product_details_data.dart';

class ProductTitleHeader extends StatelessWidget {
  final String displayArticleCode;
  final OrderabilityStatus orderStatus;
  final bool isLoading;

  const ProductTitleHeader({
    super.key,
    required this.displayArticleCode,
    required this.orderStatus,
    required this.isLoading,
  });

  Widget _buildOrderStatusChip(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    IconData iconData;
    String label;
    Color chipColor = colorScheme.primary;
    Color contentColor = colorScheme.onPrimary;

    switch (orderStatus) {
      case OrderabilityStatus.onlineAndCC:
        iconData = Icons.local_shipping_outlined;
        label = "Online & Click/Collect";
        break;
      case OrderabilityStatus.clickAndCollectOnly:
        iconData = Icons.store_mall_directory_outlined;
        label = "Alleen Click & Collect";
        break;
      case OrderabilityStatus.outOfAssortment:
        iconData = Icons.highlight_off_outlined;
        chipColor = colorScheme.error;
        contentColor = colorScheme.onError;
        label = "Uit assortiment";
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: contentColor),
          const SizedBox(width: 8),

          Flexible(
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(color: contentColor, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              softWrap: false, 
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return Row(
      children: [

        if (!isLoading && orderStatus != OrderabilityStatus.unknown)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildOrderStatusChip(context),
            ),
          ),
        

        const SizedBox(width: 16),


        if (displayArticleCode != "Laden..." && displayArticleCode != "Code?")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: clr.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.tag, size: 16, color: clr.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  displayArticleCode,
                  style: txt.labelLarge?.copyWith(
                    color: clr.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}