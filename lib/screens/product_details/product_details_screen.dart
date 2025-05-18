import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../models/product.dart';
import '../scanner_screen.dart';
import 'core/product_details_data.dart';
import 'core/product_html_parser.dart';
import 'widgets/product_image_header.dart';
import 'widgets/product_stock_list.dart';
import 'widgets/product_info_section.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../home_page.dart'; // Voor UnderConstructionScreen

class ProductDetailsScreen extends StatefulWidget
{
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
{
  String _displayPageTitle = "Laden...";
  String _displayPageArticleCode = "Laden...";
  String? _displayPageEan;
  String? _description;
  String? _specifications;
  String? _detailImageUrl;
  String? _detailPriceString;
  String? _detailOldPriceString;
  String? _detailDiscountLabel;
  String? _detailPromotionDescription;
  String? _detailPricePerUnitString;
  String? _detailPriceUnit;
  String? _detailPricePerUnitLabel;
  bool _isLoadingDetails = true;
  String? _detailsError;
  bool _isLoadingStock = true;
  Map<String, int?> _storeStocks = {};
  String? _stockError;
  OrderabilityStatus _orderStatus = OrderabilityStatus.unknown;
  List<ProductVariant> _productVariants = [];

  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  final Map<String, String> _targetStores =
  {
    'Gamma Haarlem': '39',
    'Gamma Velserbroek': '858',
    'Gamma Cruquius': '669',
    'Gamma Hoofddorp': '735',
    'Gamma Heemskerk': '857',
    'Karwei Haarlem': '647',
    'Karwei Haarlem-Zuid': '844',
  };
  static const String _gammaStockApiBase = 'https://api.gamma.nl/stock/2/';
  static const String _karweiStockApiBase = 'https://api.karwei.nl/stock/2/';
  static const String _gammaCookieName = 'PREFERRED-STORE-UID';
  static const String _gammaCookieValueHaarlem = '39';
  final RegExp _ean13Regex = RegExp(r'^[0-9]{13}$');

  @override
  void initState()
  {
    super.initState();
    _displayPageTitle = widget.product.title;
    _displayPageArticleCode = widget.product.articleCode;
    _displayPageEan = widget.product.eanCode;
    _initializeProductData(widget.product);
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    if (widget.product.productUrl != oldWidget.product.productUrl || 
        widget.product.articleCode != oldWidget.product.articleCode) {
      setState(() {
        _displayPageTitle = widget.product.title;
        _displayPageArticleCode = widget.product.articleCode;
        _displayPageEan = widget.product.eanCode;
      });
      _initializeProductData(widget.product);
    }
  }

  void _initializeProductData(Product product)
  {
    setState(() {
      _description = null;
      _specifications = null;
      _detailImageUrl = product.imageUrl;
      _detailPriceString = product.priceString;
      _detailOldPriceString = product.oldPriceString;
      _detailDiscountLabel = product.discountLabel;
      _detailPromotionDescription = product.promotionDescription;
      _detailPricePerUnitString = product.pricePerUnitString;
      _detailPriceUnit = product.priceUnit?.replaceAll('m²', 'm2');
      _detailPricePerUnitLabel = product.pricePerUnitLabel;
      _orderStatus = OrderabilityStatus.unknown;
      _productVariants = [];
      _storeStocks = {};
      _stockError = null;
      _detailsError = null;
      _isLoadingDetails = true;
      _isLoadingStock = true;
    });

    _fetchProductDetails(product);
  }

  Future<void> _fetchProductDetails(Product currentProduct) async
  {
    if (!mounted) return;
    setState(() { _isLoadingDetails = true; _detailsError = null; });


    if (currentProduct.productUrl == null || currentProduct.productUrl!.isEmpty)
    {
      if (mounted)
      {
        setState(()
        {
          _detailsError = "Product URL ontbreekt.";
          _isLoadingDetails = false;
          _isLoadingStock = false;
        });
      }
      return;
    }

    final String currentUrl = currentProduct.productUrl!;

    try
    {
      final response = await http.get(Uri.parse(currentUrl), headers: {'User-Agent': _userAgent});
      if (!mounted) return;

      if (response.statusCode == 200)
      {
        final responseBody = utf8.decode(response.bodyBytes);
        
        final Map<String, String> isolateArgs = {
          'htmlBody': responseBody,
          'currentProductUrl': currentUrl,
        };

        final result = await compute(parseProductDetailsHtmlIsolate, isolateArgs);
        
        if (!mounted) return;

        String finalArticleCode = result.scrapedArticleCode ?? _displayPageArticleCode;
        String? finalEanCode = result.scrapedEan ?? _displayPageEan;

        setState(()
        {
          _displayPageTitle = result.scrapedTitle ?? _displayPageTitle;
          _displayPageArticleCode = finalArticleCode;
          _displayPageEan = finalEanCode;

          _description = result.description ?? _description;
          _specifications = result.specifications ?? _specifications;
          _detailImageUrl = result.imageUrl ?? _detailImageUrl;
          _detailPriceString = result.priceString ?? _detailPriceString;
          _detailOldPriceString = result.oldPriceString ?? _detailOldPriceString;
          _detailPriceUnit = result.priceUnit ?? _detailPriceUnit;
          _detailPricePerUnitString = result.pricePerUnitString ?? _detailPricePerUnitString;
          _detailPricePerUnitLabel = result.pricePerUnitLabel ?? _detailPricePerUnitLabel;
          _detailDiscountLabel = result.discountLabel ?? _detailDiscountLabel;
          _detailPromotionDescription = result.promotionDescription ?? _detailPromotionDescription;
          _orderStatus = result.status;
          _productVariants = result.variants;
          _isLoadingDetails = false;

          if (_description == null && _specifications == null && result.priceString == null && _productVariants.isEmpty && result.scrapedTitle == null)
          {
            _detailsError = 'Kon geen details of varianten uit de productpagina lezen.';
             _isLoadingStock = false;
          }
          else
          {
            _detailsError = null;
          }
        });

        if (finalArticleCode != "Laden..." && finalArticleCode != "Code?") {
          final Product productForStockCheck = Product(
              title: _displayPageTitle,
              articleCode: finalArticleCode,
              eanCode: finalEanCode,
              productUrl: currentUrl
              );
          _fetchSpecificStoreStocks(productForStockCheck);
        } else {
          setState(() {
              _stockError = "Kon artikelcode niet bepalen voor voorraadcheck.";
              _isLoadingStock = false;
          });
        }

      }
      else
      {
        if (mounted) {
          setState(() {
            _detailsError = 'Fout bij laden details: Server status ${response.statusCode}';
            _isLoadingDetails = false;
            _isLoadingStock = false;
          });
        }
      }
    }
    catch (e)
    {
      if (mounted) {
        setState(() {
          _detailsError = 'Fout bij verwerken productpagina: $e';
          _isLoadingDetails = false;
          _isLoadingStock = false;
        });
      }
    }
  }

  Future<void> _fetchSpecificStoreStocks(Product currentProduct) async
  {
    if (!mounted) return;
    setState(() { _isLoadingStock = true; _stockError = null; });

    String productId = currentProduct.articleCode; 
    if (productId == 'Laden...' || productId == 'Code?' || productId == 'Code niet gevonden')
    {
      if (mounted)
      {
        setState(()
        {
          _stockError = "Artikelcode nog niet geladen, kan voorraad niet ophalen.";
          _isLoadingStock = false;
        });
      }
      return;
    }
    try
    {
        productId = int.parse(productId).toString();
    }
    catch (e)
    {
        // no-op
    }

    Map<String, int?> finalStocks = {};
    List<String> errors = [];

    final gammaEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma'));
    final karweiEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei'));

    void parseStockResponse(String responseBody, Iterable<MapEntry<String,String>> entries, Map<String, int?> targetStockMap, String brand)
    {
      try
      {
        final decoded = jsonDecode(responseBody) as List;
        for (var entry in entries)
        {
          final storeId = entry.value;
          final storeName = entry.key;
          final uidToFind = 'Stock-$storeId-$productId';
          var stockItem = decoded.firstWhere((item) => item is Map && item['uid'] == uidToFind, orElse: () => null);

          if (stockItem != null)
          {
            final quantity = stockItem['quantity'];
            if (quantity is int)
            {
                targetStockMap[storeName] = quantity;
            }
            else if (quantity is String)
            {
                targetStockMap[storeName] = int.tryParse(quantity);
            }
            else
            {
                targetStockMap[storeName] = null;
            }
          }
          else
          {
            targetStockMap[storeName] = null;
          }
        }
      }
      catch (e)
      {
        errors.add('$brand parse');
      }
    }

    if (gammaEntries.isNotEmpty)
    {
      final gammaParam = gammaEntries.map((e) => 'Stock-${e.value}-$productId').join(',');
      final gammaUrl = Uri.parse('$_gammaStockApiBase?uids=$gammaParam');
      final gammaHeaders =
      {
        'User-Agent': _userAgent,
        'Origin': 'https://www.gamma.nl',
        'Referer': 'https://www.gamma.nl/',
        'Cookie': '$_gammaCookieName=$_gammaCookieValueHaarlem'
      };
      try
      {
        final response = await http.get(gammaUrl, headers: gammaHeaders);
        if (response.statusCode == 200)
        {
          parseStockResponse(response.body, gammaEntries, finalStocks, "Gamma");
        }
        else
        {
          errors.add('G-${response.statusCode}');
          for (var entry in gammaEntries)
          {
              finalStocks[entry.key] = null;
          }
        }
      }
      catch (e)
      {
        errors.add('G-Net');
        for (var entry in gammaEntries)
        {
            finalStocks[entry.key] = null;
        }
      }
    }

    if (karweiEntries.isNotEmpty)
    {
      final karweiParam = karweiEntries.map((e) => 'Stock-${e.value}-$productId').join(',');
      final karweiUrl = Uri.parse('$_karweiStockApiBase?uids=$karweiParam');
      final karweiHeaders =
      {
        'User-Agent': _userAgent,
        'Origin':'https://www.karwei.nl',
        'Referer':'https://www.karwei.nl/'
      };
      try
      {
        final response = await http.get(karweiUrl, headers: karweiHeaders);
        if (response.statusCode == 200)
        {
          parseStockResponse(response.body, karweiEntries, finalStocks, "Karwei");
        }
        else
        {
          errors.add('K-${response.statusCode}');
          for (var entry in karweiEntries)
          {
              finalStocks[entry.key] = null;
          }
        }
      }
      catch (e)
      {
        errors.add('K-Net');
        for (var entry in karweiEntries)
        {
            finalStocks[entry.key] = null;
        }
      }
    }

    if (mounted)
    {
      setState(()
      {
        _storeStocks = finalStocks;
        _stockError = errors.isEmpty ? null : "Fout bij ophalen voorraad: ${errors.join(', ')}";
        _isLoadingStock = false;
      });
    }
  }

  Future<void> _navigateToScannerFromDetailsAndReplace() async {
    try {
      final String? scanResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const ScannerScreen()),
      );

      if (!mounted) return;

      if (scanResult != null && scanResult.isNotEmpty) {
        Navigator.pop(context, scanResult); 
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij openen scanner: $e')),
      );
    }
  }

  void _showPromotionDetails()
  {
    if (_detailPromotionDescription == null || _detailPromotionDescription!.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context)
      {
        return AlertDialog(
          title: Text(_detailDiscountLabel ?? "Actie Details"),
          content: SingleChildScrollView(
            child: Text(_detailPromotionDescription!),
          ),
          actions: <Widget>
          [
            TextButton(
              child: const Text('Sluiten'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<ProductVariant>> _getGroupedVariants() {
    final Map<String, List<ProductVariant>> grouped = {};
    for (var variant in _productVariants) {
      (grouped[variant.groupName] ??= []).add(variant);
    }
    return grouped;
  }

  void _navigateToVariant(ProductVariant variant) {
    if (variant.isSelected) return;

    final variantProduct = Product(
        title: variant.variantName,
        articleCode: "Laden...", 
        productUrl: variant.productUrl,
        eanCode: null, 
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: variantProduct),
      ),
    );
  }

  void _navigateToZaagTool(BuildContext context, Product product) {
     Navigator.push(context, MaterialPageRoute(builder: (context) => const UnderConstructionScreen(pageName: "Zaagplan")));
   }

  void _onBottomNavTabSelectedOnDetailsPage(BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.agenda:
        Navigator.push(context, MaterialPageRoute(builder: (context) =>
          Scaffold(appBar: AppBar(title: const Text("Agenda (Placeholder)")), body: const Center(child: Text("Agenda Scherm"))),
        ));
        break;
      case BottomNavTab.zaagtool:
        _navigateToZaagTool(context, widget.product);
        break;
      case BottomNavTab.scanner:
        _navigateToScannerFromDetailsAndReplace();
        break;
    }
  }

  Widget _buildVariantSelector() {
    if (_productVariants.isEmpty || _isLoadingDetails) {
      return const SizedBox.shrink();
    }

    final grouped = _getGroupedVariants();
    if (grouped.isEmpty) {
        return const SizedBox.shrink();
    }
    final List<Widget> variantWidgets = [];
    final ColorScheme clr = Theme.of(context).colorScheme;
    final TextTheme txt = Theme.of(context).textTheme;


    grouped.forEach((groupName, variantsInGroup) {
      variantWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(groupName, style: txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        )
      );
      variantWidgets.add(
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: variantsInGroup.map((variant) {
            return ChoiceChip(
              label: Text(variant.variantName),
              selected: variant.isSelected,
              onSelected: (selected) {
                if (selected && !variant.isSelected) {
                  _navigateToVariant(variant);
                }
              },
              selectedColor: clr.primary.withAlpha((0.15 * 255).round()),
              labelStyle: TextStyle(
                color: variant.isSelected
                    ? clr.primary
                    : clr.onSurface.withAlpha((0.8 * 255).round()),
                fontWeight: variant.isSelected ? FontWeight.bold : FontWeight.normal
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: variant.isSelected ? clr.primary : clr.outline.withAlpha((0.5 * 255).round()),
                  width: variant.isSelected ? 1.5 : 1.0,
                )
              ),
              backgroundColor: clr.surfaceContainerLowest,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        )
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: variantWidgets,
    );
  }


  @override
  Widget build(BuildContext context)
  {
    final TextTheme txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayPageTitle, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
          [
            ProductImageHeader(
              product: widget.product, 
              displayTitle: _displayPageTitle,
              displayArticleCode: _displayPageArticleCode,
              displayEan: _displayPageEan, 
              detailImageUrl: _detailImageUrl,
              detailPriceString: _detailPriceString,
              detailOldPriceString: _detailOldPriceString,
              detailPriceUnit: _detailPriceUnit,
              detailPricePerUnitString: _detailPricePerUnitString,
              detailPricePerUnitLabel: _detailPricePerUnitLabel,
              detailDiscountLabel: _detailDiscountLabel,
              detailPromotionDescription: _detailPromotionDescription,
              orderStatus: _orderStatus,
              isLoadingDetails: _isLoadingDetails,
              onShowPromotionDetails: _showPromotionDetails,
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildVariantSelector(),
            ),

            if (_productVariants.isNotEmpty) const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Voorraad:', style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: txt.headlineSmall?.color)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ProductStockList(
                isLoadingStock: _isLoadingStock,
                stockError: _stockError,
                storeStocks: _storeStocks,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(thickness: 0.5),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ProductInfoSection(
                isLoadingDetails: _isLoadingDetails,
                description: _description,
                specifications: _specifications,
                detailsError: _detailsError,
              ),
            ),
            if (_detailsError != null && _description == null && _specifications == null && !_isLoadingDetails && _productVariants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                child: Center(
                  child: Text(
                    _detailsError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        onTabSelected: _onBottomNavTabSelectedOnDetailsPage,
      ),
    );
  }
}