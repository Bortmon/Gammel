// lib/models/product.dart

class Product {
  final String title;
  final String articleCode;
  final String? eanCode;
  final String? imageUrl;
  final String? productUrl;
  final String? priceString;          // Huidige prijs waarde
  final String? priceUnit;            // Eenheid van hoofdprijs (bv. "/m²") - NIEUW
  final String? oldPriceString;       // Oude prijs waarde
  final String? discountLabel;        // Kortingslabel
  final String? promotionDescription;
  final String? pricePerUnitString;   // Prijs per stuk/eenheid waarde
  final String? pricePerUnitLabel;    // Label voor prijs per stuk (bv. "Per stuk") - NIEUW

  Product({
    required this.title,
    required this.articleCode,
    this.eanCode,
    this.imageUrl,
    this.productUrl,
    this.priceString,
    this.priceUnit, // <-- Toevoegen
    this.oldPriceString,
    this.discountLabel,
    this.promotionDescription,
    this.pricePerUnitString,
    this.pricePerUnitLabel, // <-- Toevoegen
  });

  @override
  String toString() {
    return 'Product(title: $title, articleCode: $articleCode, eanCode: $eanCode, price: $priceString $priceUnit, oldPrice: $oldPriceString, pricePerUnit: $pricePerUnitString $pricePerUnitLabel, discount: $discountLabel, promoDesc: $promotionDescription, imageUrl: $imageUrl, productUrl: $productUrl)';
  }
}