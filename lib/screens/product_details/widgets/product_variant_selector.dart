import 'package:flutter/material.dart';
import '../core/product_details_data.dart';

class ProductVariantSelector extends StatefulWidget {
  final List<ProductVariant> variants;
  final Function(ProductVariant) onVariantSelected;

  const ProductVariantSelector({
    super.key,
    required this.variants,
    required this.onVariantSelected,
  });

  @override
  State<ProductVariantSelector> createState() => _ProductVariantSelectorState();
}

class _ProductVariantSelectorState extends State<ProductVariantSelector> {
  String? _openVariantGroupName;

  Map<String, List<ProductVariant>> _getGroupedVariants() {
    final Map<String, List<ProductVariant>> grouped = {};
    for (var variant in widget.variants) {
      (grouped[variant.groupName] ??= []).add(variant);
    }
    return grouped;
  }

  void _toggleVariantGroup(String groupName) {
    setState(() {
      if (_openVariantGroupName == groupName) {
        _openVariantGroupName = null;
      } else {
        _openVariantGroupName = groupName;
      }
    });
  }
  
  IconData _getIconForVariantGroup(String groupName) {
    final lowerCaseGroup = groupName.toLowerCase();
    if (lowerCaseGroup.contains('afmeting')) return Icons.straighten_outlined;
    if (lowerCaseGroup.contains('dikte')) return Icons.layers_outlined;
    if (lowerCaseGroup.contains('kleur')) return Icons.color_lens_outlined;
    return Icons.tune_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _getGroupedVariants();
    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    final clr = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: clr.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Kies een uitvoering",
            style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          ...grouped.entries.map((entry) {
            final groupName = entry.key;
            final variantsInGroup = entry.value;
            final currentlySelected = variantsInGroup.firstWhere((v) => v.isSelected, orElse: () => variantsInGroup.first);

            return _buildSingleVariantSelector(
              context: context,
              groupName: groupName,
              variantsInGroup: variantsInGroup,
              currentlySelected: currentlySelected,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSingleVariantSelector({
    required BuildContext context,
    required String groupName,
    required List<ProductVariant> variantsInGroup,
    required ProductVariant currentlySelected,
  }) {
    final clr = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;
    final bool isOpen = _openVariantGroupName == groupName;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForVariantGroup(groupName), size: 16, color: clr.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                groupName,
                style: txt.bodyMedium?.copyWith(color: clr.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: clr.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12.0),
            child: InkWell(
              onTap: () => _toggleVariantGroup(groupName),
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        currentlySelected.variantName,
                        style: txt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: clr.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: isOpen
                ? Container(
                    margin: const EdgeInsets.only(top: 4.0),
                    decoration: BoxDecoration(
                      color: clr.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Column(
                      children: variantsInGroup.map((variant) {
                        final isSelected = variant.isSelected;
                        return Material(
                          color: isSelected ? clr.primary.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.0),
                          child: InkWell(
                            onTap: isSelected ? null : () => widget.onVariantSelected(variant),
                            borderRadius: BorderRadius.circular(8.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      variant.variantName,
                                      style: txt.bodyLarge?.copyWith(
                                        color: isSelected ? clr.primary : clr.onSurface,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) Icon(Icons.check, color: clr.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}