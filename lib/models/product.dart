// lib/models/product.dart

class Product {
  final String title;
  final String articleCode;
  final String? eanCode;
  final String? imageUrl;
  final String? productUrl;
  final String? priceString;

  Product({
    required this.title,
    required this.articleCode,
    this.eanCode,
    this.imageUrl,
    this.productUrl,
    this.priceString,
  });

  @override
  String toString() {
    return 'Product(title: $title, articleCode: $articleCode, eanCode: $eanCode, price: $priceString, imageUrl: $imageUrl, productUrl: $productUrl)';
  }
}