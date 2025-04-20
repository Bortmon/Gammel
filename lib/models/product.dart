// lib/models/product.dart

class Product {
  final String title;
  final String articleCode;
  final String? eanCode;
  final String? imageUrl;
  final String? productUrl;
  final String? priceString;      // Prijs (bv. per m2 of actieprijs per stuk)
  final String? oldPriceString;   // Oude prijs (bv. per m2)
  final String? discountLabel;    // Kortingslabel
  final String? promotionDescription;
  final String? pricePerUnitString; // <-- NIEUW: Prijs per stuk/eenheid

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
    this.pricePerUnitString, // <-- Toevoegen aan constructor
  });

  @override
  String toString() {
    return 'Product(title: $title, articleCode: $articleCode, eanCode: $eanCode, price: $priceString, oldPrice: $oldPriceString, pricePerUnit: $pricePerUnitString, discount: $discountLabel, promoDesc: $promotionDescription, imageUrl: $imageUrl, productUrl: $productUrl)';
  }
}