// lib/models/product.dart

class Product {
  final String title;
  final String articleCode;
  final String? eanCode;
  final String? imageUrl;
  final String? productUrl;
  final String? priceString;
  final String? oldPriceString;
  final String? discountLabel;
  final String? promotionDescription; 

  Product({
    required this.title,
    required this.articleCode,
    this.eanCode,
    this.imageUrl,
    this.productUrl,
    this.priceString,
    this.oldPriceString,
    this.discountLabel,
    this.promotionDescription, 
  });

  @override
  String toString() {
    return 'Product(title: $title, articleCode: $articleCode, eanCode: $eanCode, price: $priceString, oldPrice: $oldPriceString, discount: $discountLabel, promoDesc: $promotionDescription, imageUrl: $imageUrl, productUrl: $productUrl)';
  }
}