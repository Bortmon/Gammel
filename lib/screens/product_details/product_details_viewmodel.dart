import 'package:flutter/material.dart';
import '../../services/product_repository.dart';
import 'core/product_details_data.dart';
import '../../models/product.dart';
import 'product_details_screen.dart'; 

enum ViewState { loading, success, error }

class ProductDetailsViewModel extends ChangeNotifier {
  final ProductRepository _productRepository;

  ProductDetailsViewModel({required ProductRepository repository}) : _productRepository = repository;

  ViewState _state = ViewState.loading;
  ViewState get state => _state;

  bool _isStockLoading = true;
  bool get isStockLoading => _isStockLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _stockErrorMessage;
  String? get stockErrorMessage => _stockErrorMessage;

  ProductDetailsScrapeResult? _productDetails;
  ProductDetailsScrapeResult? get productDetails => _productDetails;
  
  Map<String, int?> _storeStocks = {};
  Map<String, int?> get storeStocks => _storeStocks;
  
  Product? _initialProduct;
  Product? get initialProduct => _initialProduct;
  
  String? _productDimensionsFromParse;
  String? get productDimensionsFromParse => _productDimensionsFromParse;


  Future<void> loadDataForProduct(Product product) async {
    _initialProduct = product;
    _state = ViewState.loading;
    _isStockLoading = true;
    _errorMessage = null;
    _stockErrorMessage = null;
    _productDetails = null;
    _storeStocks = {};
    notifyListeners();

    try {
      if (product.productUrl == null || product.productUrl!.isEmpty) {
        throw DataFetchingException("Product URL ontbreekt.");
      }
      
      final details = await _productRepository.fetchProductDetails(product.productUrl!);
      _productDetails = details;
      _state = ViewState.success;
      _parseDimensions();
      notifyListeners();

      if (details.scrapedArticleCode != null) {
        try {
          final stocks = await _productRepository.fetchStoreStocks(details.scrapedArticleCode!);
          _storeStocks = stocks;
        } catch (e) {
          _stockErrorMessage = e.toString();
        }
      } else {
        _stockErrorMessage = "Artikelcode niet gevonden voor voorraadcheck.";
      }

    } on DataFetchingException catch (e) {
      _errorMessage = e.message;
      _state = ViewState.error;
    } catch (e) {
      _errorMessage = "Een onverwachte fout is opgetreden: ${e.toString()}";
      _state = ViewState.error;
    } finally {
      _isStockLoading = false;
      notifyListeners();
    }
  }
  
  void _parseDimensions() {
    if (_productDetails?.specifications == null) {
      _productDimensionsFromParse = null;
      return;
    }
    final RegExp dimRegex = RegExp(r'Afmetingen:\s*([^\n]+)', caseSensitive: false);
    final RegExp thicknessRegex = RegExp(r'Dikte:\s*([^\n]+)', caseSensitive: false);
    final dimMatch = dimRegex.firstMatch(_productDetails!.specifications!);
    final thicknessMatch = thicknessRegex.firstMatch(_productDetails!.specifications!);
    if (dimMatch != null) {
      _productDimensionsFromParse = dimMatch.group(1)?.trim();
    } else if (thicknessMatch != null) {
      _productDimensionsFromParse = thicknessMatch.group(1)?.trim();
    } else {
      _productDimensionsFromParse = null;
    }
  }

  void showPromotionDetails(BuildContext context) {
    if (_productDetails?.promotionDescription == null || _productDetails!.promotionDescription!.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_productDetails?.discountLabel ?? "Actie Details"),
          content: SingleChildScrollView(
            child: Text(_productDetails!.promotionDescription!),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Sluiten'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void navigateToVariant(BuildContext context, ProductVariant variant) {
    if (variant.isSelected) return;

    final variantProduct = Product(
      title: variant.variantName,
      articleCode: "Laden...",
      productUrl: variant.productUrl,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: variantProduct),
      ),
    );
  }
}