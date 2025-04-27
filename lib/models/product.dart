// lib/models/product.dart

class Product
{
  final String title;
  final String articleCode;
  final String? eanCode;
  final String? imageUrl;
  final String? productUrl;
  final String? priceString;
  final String? priceUnit;
  final String? oldPriceString;
  final String? discountLabel;
  final String? promotionDescription;
  final String? pricePerUnitString;
  final String? pricePerUnitLabel;

  Product({
    required this.title,
    required this.articleCode,
    this.eanCode,
    this.imageUrl,
    this.productUrl,
    this.priceString,
    this.priceUnit,
    this.oldPriceString,
    this.discountLabel,
    this.promotionDescription,
    this.pricePerUnitString,
    this.pricePerUnitLabel,
  });

  @override
  String toString()
  {
    return 'Product(title: $title, articleCode: $articleCode, eanCode: $eanCode, price: $priceString $priceUnit, oldPrice: $oldPriceString, pricePerUnit: $pricePerUnitString $pricePerUnitLabel, discount: $discountLabel, promoDesc: $promotionDescription, imageUrl: $imageUrl, productUrl: $productUrl)';
  }
}