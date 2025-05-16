enum OrderabilityStatus
{
  onlineAndCC,
  clickAndCollectOnly,
  outOfAssortment,
  unknown
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
  });
}