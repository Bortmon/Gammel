import 'package:flutter/material.dart';

class ProductTitleHeader extends StatelessWidget {
  final String displayTitle;
  final String displayArticleCode;
  final String? productDimensions;

  const ProductTitleHeader({
    super.key,
    required this.displayTitle,
    required this.displayArticleCode,
    this.productDimensions,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  displayTitle,
                  style: txt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: clr.onBackground),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: clr.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Art: $displayArticleCode",
                  style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (productDimensions != null && productDimensions!.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                productDimensions!,
                style: txt.bodyMedium?.copyWith(color: clr.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}