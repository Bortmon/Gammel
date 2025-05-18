enum OrderabilityStatus
{
  onlineAndCC,
  clickAndCollectOnly,
  outOfAssortment,
  unknown
}

class ProductVariant { 
  final String groupName;
  final String variantName;
  final String productUrl;
  final bool isSelected;

  ProductVariant({ 
    required this.groupName,
    required this.variantName,
    required this.productUrl,
    required this.isSelected,
  });
}

class ProductDetailsScrapeResult
{
  final OrderabilityStatus status;
  final String? description;
  final String? specifications;
  final String? imageUrl;
  final String? priceString;
  final String? oldPriceString;
  final String? priceUnit;
  final String? pricePerUnitString;
  final String? pricePerUnitLabel;
  final String? discountLabel;
  final String? promotionDescription;
  final List<ProductVariant> variants; 
  final String? scrapedTitle;
  final String? scrapedArticleCode;
  final String? scrapedEan;

  ProductDetailsScrapeResult(
  {
    this.status = OrderabilityStatus.unknown,
    this.description,
    this.specifications,
    this.imageUrl,
    this.priceString,
    this.oldPriceString,
    this.priceUnit,
    this.pricePerUnitString,
    this.pricePerUnitLabel,
    this.discountLabel,
    this.promotionDescription,
    this.variants = const [],
    this.scrapedTitle,
    this.scrapedArticleCode,
    this.scrapedEan,
  });
}