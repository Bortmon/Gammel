import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../models/product.dart';
import '../scanner_screen.dart';
import 'core/product_details_data.dart';
import 'core/product_html_parser.dart';
import 'widgets/product_stock_list.dart';
import 'widgets/product_info_section.dart';
import '../../widgets/custom_bottom_nav_bar.dart';
import '../home_page.dart';
import 'widgets/product_gallery_view.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> with TickerProviderStateMixin {
  String _displayPageTitle = "Laden...";
  String _displayPageArticleCode = "Laden...";
  String? _displayPageEan;
  String? _productDimensionsFromParse;
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
  Map<String, ProductVariant?> _selectedVariants = {};
  List<String> _galleryImageUrls = [];
  String? _deliveryCost;
  String? _deliveryFreeFrom;
  String? _deliveryTime;
  late TabController _availabilityTabController;
  int _availabilityTabIndex = 0;
  String? _openVariantGroupName;

  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  final Map<String, String> _targetStores = {
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

  @override
  void initState() {
    super.initState();
    _availabilityTabController = TabController(length: 2, vsync: this);
    _availabilityTabController.addListener(() {
      if (_availabilityTabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          _availabilityTabIndex = _availabilityTabController.index;
        });
      }
    });

    _displayPageTitle = widget.product.title;
    _displayPageArticleCode = widget.product.articleCode;
    _displayPageEan = widget.product.eanCode;
    _initializeProductData(widget.product);
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.product.productUrl != oldWidget.product.productUrl ||
        widget.product.articleCode != oldWidget.product.articleCode) {
      setState(() {
        _displayPageTitle = widget.product.title;
        _displayPageArticleCode = widget.product.articleCode;
        _displayPageEan = widget.product.eanCode;
        _selectedVariants = {};
        _productDimensionsFromParse = null;
        _openVariantGroupName = null;
      });
      _initializeProductData(widget.product);
    }
  }

  @override
  void dispose() {
    _availabilityTabController.dispose();
    super.dispose();
  }

  void _initializeProductData(Product product) {
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
      _galleryImageUrls = [];
      _deliveryCost = null;
      _deliveryFreeFrom = null;
      _deliveryTime = null;
      _storeStocks = {};
      _stockError = null;
      _detailsError = null;
      _isLoadingDetails = true;
      _isLoadingStock = true;
    });

    _fetchProductDetails(product);
  }

  Future<void> _fetchProductDetails(Product currentProduct) async {
    if (!mounted) return;
    setState(() {
      _isLoadingDetails = true;
      _detailsError = null;
    });

    if (currentProduct.productUrl == null || currentProduct.productUrl!.isEmpty) {
      if (mounted) {
        setState(() {
          _detailsError = "Product URL ontbreekt.";
          _isLoadingDetails = false;
          _isLoadingStock = false;
        });
      }
      return;
    }

    final String currentUrl = currentProduct.productUrl!;

    try {
      final response = await http.get(Uri.parse(currentUrl), headers: {'User-Agent': _userAgent});
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);

        final Map<String, String> isolateArgs = {
          'htmlBody': responseBody,
          'currentProductUrl': currentUrl,
        };

        final result = await compute(parseProductDetailsHtmlIsolate, isolateArgs);

        if (!mounted) return;

        String finalArticleCode = result.scrapedArticleCode ?? _displayPageArticleCode;
        String? finalEanCode = result.scrapedEan ?? _displayPageEan;
        Map<String, ProductVariant?> initialSelectedVariants = {};
        for (var variant in result.variants) {
          if (variant.isSelected) {
            initialSelectedVariants[variant.groupName] = variant;
          }
        }

        String? parsedDimensions;
        if (result.specifications != null) {
          final RegExp dimRegex = RegExp(r'Afmetingen:\s*([^\n]+)', caseSensitive: false);
          final RegExp thicknessRegex = RegExp(r'Dikte:\s*([^\n]+)', caseSensitive: false);
          final dimMatch = dimRegex.firstMatch(result.specifications!);
          final thicknessMatch = thicknessRegex.firstMatch(result.specifications!);
          if (dimMatch != null) {
            parsedDimensions = dimMatch.group(1)?.trim();
          } else if (thicknessMatch != null) {
            parsedDimensions = thicknessMatch.group(1)?.trim();
          }
        }

        setState(() {
          _displayPageTitle = result.scrapedTitle ?? _displayPageTitle;
          _displayPageArticleCode = finalArticleCode;
          _displayPageEan = finalEanCode;
          _productDimensionsFromParse = parsedDimensions;

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
          _galleryImageUrls = result.galleryImageUrls;
          if (_detailImageUrl == null && result.galleryImageUrls.isNotEmpty) {
            _detailImageUrl = result.galleryImageUrls.first;
          }
          _selectedVariants = initialSelectedVariants;
          _deliveryCost = result.deliveryCost;
          _deliveryFreeFrom = result.deliveryFreeFrom;
          _deliveryTime = result.deliveryTime;
          _isLoadingDetails = false;

          if (_description == null &&
              _specifications == null &&
              result.priceString == null &&
              _productVariants.isEmpty &&
              result.scrapedTitle == null) {
            _detailsError = 'Kon geen details of varianten uit de productpagina lezen.';
            _isLoadingStock = false;
          } else {
            _detailsError = null;
          }
        });

        if (finalArticleCode != "Laden..." && finalArticleCode != "Code?") {
          final Product productForStockCheck = Product(
              title: _displayPageTitle,
              articleCode: finalArticleCode,
              eanCode: finalEanCode,
              productUrl: currentUrl);
          _fetchSpecificStoreStocks(productForStockCheck);
        } else {
          setState(() {
            _stockError = "Kon artikelcode niet bepalen voor voorraadcheck.";
            _isLoadingStock = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _detailsError = 'Fout bij laden details: Server status ${response.statusCode}';
            _isLoadingDetails = false;
            _isLoadingStock = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _detailsError = 'Fout bij verwerken productpagina: $e';
          _isLoadingDetails = false;
          _isLoadingStock = false;
        });
      }
    }
  }

  Future<void> _fetchSpecificStoreStocks(Product currentProduct) async {
    if (!mounted) return;
    setState(() {
      _isLoadingStock = true;
      _stockError = null;
    });

    String productId = currentProduct.articleCode;
    if (productId == 'Laden...' || productId == 'Code?' || productId == 'Code niet gevonden') {
      if (mounted) {
        setState(() {
          _stockError = "Artikelcode nog niet geladen, kan voorraad niet ophalen.";
          _isLoadingStock = false;
        });
      }
      return;
    }
    try {
      productId = int.parse(productId).toString();
    } catch (e) {
      // no-op
    }

    Map<String, int?> finalStocks = {};
    List<String> errors = [];

    final gammaEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma'));
    final karweiEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei'));

    void parseStockResponse(String responseBody, Iterable<MapEntry<String, String>> entries,
        Map<String, int?> targetStockMap, String brand) {
      try {
        final decoded = jsonDecode(responseBody) as List;
        for (var entry in entries) {
          final storeId = entry.value;
          final storeName = entry.key;
          final uidToFind = 'Stock-$storeId-$productId';
          var stockItem = decoded.firstWhere((item) => item is Map && item['uid'] == uidToFind, orElse: () => null);

          if (stockItem != null) {
            final quantity = stockItem['quantity'];
            if (quantity is int) {
              targetStockMap[storeName] = quantity;
            } else if (quantity is String) {
              targetStockMap[storeName] = int.tryParse(quantity);
            } else {
              targetStockMap[storeName] = null;
            }
          } else {
            targetStockMap[storeName] = null;
          }
        }
      } catch (e) {
        errors.add('$brand parse');
      }
    }

    if (gammaEntries.isNotEmpty) {
      final gammaParam = gammaEntries.map((e) => 'Stock-${e.value}-$productId').join(',');
      final gammaUrl = Uri.parse('$_gammaStockApiBase?uids=$gammaParam');
      final gammaHeaders = {
        'User-Agent': _userAgent,
        'Origin': 'https://www.gamma.nl',
        'Referer': 'https://www.gamma.nl/',
        'Cookie': '$_gammaCookieName=$_gammaCookieValueHaarlem'
      };
      try {
        final response = await http.get(gammaUrl, headers: gammaHeaders);
        if (response.statusCode == 200) {
          parseStockResponse(response.body, gammaEntries, finalStocks, "Gamma");
        } else {
          errors.add('G-${response.statusCode}');
          for (var entry in gammaEntries) {
            finalStocks[entry.key] = null;
          }
        }
      } catch (e) {
        errors.add('G-Net');
        for (var entry in gammaEntries) {
          finalStocks[entry.key] = null;
        }
      }
    }

    if (karweiEntries.isNotEmpty) {
      final karweiParam = karweiEntries.map((e) => 'Stock-${e.value}-$productId').join(',');
      final karweiUrl = Uri.parse('$_karweiStockApiBase?uids=$karweiParam');
      final karweiHeaders = {
        'User-Agent': _userAgent,
        'Origin': 'https://www.karwei.nl',
        'Referer': 'https://www.karwei.nl/'
      };
      try {
        final response = await http.get(karweiUrl, headers: karweiHeaders);
        if (response.statusCode == 200) {
          parseStockResponse(response.body, karweiEntries, finalStocks, "Karwei");
        } else {
          errors.add('K-${response.statusCode}');
          for (var entry in karweiEntries) {
            finalStocks[entry.key] = null;
          }
        }
      } catch (e) {
        errors.add('K-Net');
        for (var entry in karweiEntries) {
          finalStocks[entry.key] = null;
        }
      }
    }

    if (mounted) {
      setState(() {
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

  void _showPromotionDetails() {
    if (_detailPromotionDescription == null || _detailPromotionDescription!.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_detailDiscountLabel ?? "Actie Details"),
          content: SingleChildScrollView(
            child: Text(_detailPromotionDescription!),
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
        Navigator.pop(context, 'ACTION_NAVIGATE_TO_AGENDA');
        break;
      case BottomNavTab.home:
        Navigator.popUntil(context, (route) => route.isFirst);
        break;
      case BottomNavTab.scanner:
        _navigateToScannerFromDetailsAndReplace();
        break;
    }
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

  Widget _buildProductInfoCard(TextTheme txt, ColorScheme clr) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: clr.outline.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _displayPageTitle,
                  style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              if (_displayPageArticleCode != "Laden..." && _displayPageArticleCode != "Code?")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: clr.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Art: $_displayPageArticleCode",
                    style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: GestureDetector(
                  onTap: () {
                    if (_galleryImageUrls.isNotEmpty) {
                      int initialIdx = 0;
                      if (_detailImageUrl != null && _galleryImageUrls.contains(_detailImageUrl)) {
                        initialIdx = _galleryImageUrls.indexOf(_detailImageUrl!);
                      }
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withAlpha((0.85 * 255).round()),
                        useSafeArea: false,
                        builder: (BuildContext dialogContext) {
                          return Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            child: ProductGalleryDialogContent(
                              imageUrls: _galleryImageUrls,
                              initialIndex: initialIdx,
                            ),
                          );
                        },
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: clr.surface,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: _isLoadingDetails && _detailImageUrl == null
                        ? Center(child: CircularProgressIndicator(color: clr.primary))
                        : (_detailImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Image.network(
                                  _detailImageUrl!,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (ctx, child, p) => (p == null)
                                      ? child
                                      : Center(
                                          child: CircularProgressIndicator(
                                          value: p.expectedTotalBytes != null
                                              ? p.cumulativeBytesLoaded / p.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2.0,
                                          color: clr.primary,
                                        )),
                                  errorBuilder: (ctx, err, st) => Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          size: 40, color: clr.onSurfaceVariant.withAlpha(100))),
                                ),
                              )
                            : Center(
                                child: Icon(Icons.image_not_supported_outlined,
                                    size: 40, color: clr.onSurfaceVariant.withAlpha(100)))),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingDetails && _detailPriceString == null)
                      Text("Prijs laden...", style: txt.headlineMedium?.copyWith(color: clr.onSurfaceVariant))
                    else if (_detailPriceString != null)
                      Text(
                        '€$_detailPriceString',
                        style: txt.headlineMedium?.copyWith(color: clr.secondary, fontWeight: FontWeight.bold),
                      )
                    else
                      Text('Prijs onbekend',
                          style: txt.titleLarge?.copyWith(fontStyle: FontStyle.italic, color: clr.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (_displayPageEan != null && _displayPageEan!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: clr.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_displayPageEan!,
                                  style: txt.bodyMedium?.copyWith(color: clr.onSurfaceVariant))),
                        ],
                      ),
                    const SizedBox(height: 8),
                    if (!_isLoadingDetails && _orderStatus != OrderabilityStatus.unknown)
                      Chip(
                        avatar: Icon(
                          Icons.local_shipping_outlined,
                          size: 16,
                          color: clr.onPrimary,
                        ),
                        label: Text(
                          _orderStatus == OrderabilityStatus.onlineAndCC
                              ? "Online & Click/Collect"
                              : _orderStatus == OrderabilityStatus.clickAndCollectOnly
                                  ? "Alleen Click & Collect"
                                  : _orderStatus == OrderabilityStatus.outOfAssortment
                                      ? "Uit assortiment"
                                      : "Status onbekend",
                          style: txt.labelMedium?.copyWith(color: clr.onPrimary, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: clr.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForVariantGroup(String groupName) {
    final lowerCaseGroup = groupName.toLowerCase();
    if (lowerCaseGroup.contains('afmeting')) return Icons.straighten_outlined;
    if (lowerCaseGroup.contains('dikte')) return Icons.layers_outlined;
    if (lowerCaseGroup.contains('kleur')) return Icons.color_lens_outlined;
    return Icons.tune_outlined;
  }

  Widget _buildSpecificationsCard() {
    if (_productVariants.isEmpty || _isLoadingDetails) {
      return const SizedBox.shrink();
    }

    final grouped = _getGroupedVariants();
    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    final clr = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
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
            "Product Specificaties",
            style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...grouped.entries.map((entry) {
            final groupName = entry.key;
            final variantsInGroup = entry.value;
            final currentlySelected = _selectedVariants[groupName] ?? variantsInGroup.firstWhere((v) => v.isSelected);

            return _buildSingleVariantSelector(
              groupName: groupName,
              variantsInGroup: variantsInGroup,
              currentlySelected: currentlySelected,
              isOpen: _openVariantGroupName == groupName,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSingleVariantSelector({
    required String groupName,
    required List<ProductVariant> variantsInGroup,
    required ProductVariant currentlySelected,
    required bool isOpen,
  }) {
    final clr = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

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
                    Text(
                      currentlySelected.variantName,
                      style: txt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              child: isOpen
                  ? Container(
                      margin: const EdgeInsets.only(top: 4.0),
                      decoration: BoxDecoration(
                        color: clr.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Column(
                        children: variantsInGroup.map((variant) {
                          final isSelected = variant.productUrl == currentlySelected.productUrl;
                          return Material(
                            color: isSelected ? clr.primary.withOpacity(0.2) : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (!isSelected) {
                                  _navigateToVariant(variant);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      variant.variantName,
                                      style: txt.bodyLarge?.copyWith(
                                        color: isSelected ? clr.primary : clr.onSurface,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(TextTheme txt, ColorScheme clr) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: clr.outline.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Beschikbaarheid", style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
                  label: const Text("Afhalen"),
                  onPressed: () => _availabilityTabController.animateTo(0),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: _availabilityTabIndex == 0 ? clr.onPrimary : clr.onSurface,
                    backgroundColor: _availabilityTabIndex == 0 ? clr.primary : clr.surfaceContainerHighest,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text("Bezorgen"),
                  onPressed: () => _availabilityTabController.animateTo(1),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: _availabilityTabIndex == 1 ? clr.onPrimary : clr.onSurface,
                    backgroundColor: _availabilityTabIndex == 1 ? clr.primary : clr.surfaceContainerHighest,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IndexedStack(
            index: _availabilityTabIndex,
            children: <Widget>[
              ProductStockList(
                isLoadingStock: _isLoadingStock,
                stockError: _stockError,
                storeStocks: _storeStocks,
              ),
              _buildDeliveryInfo(txt, clr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo(TextTheme txt, ColorScheme clr) {
    if (_isLoadingDetails && _deliveryTime == null && _deliveryCost == null && _deliveryFreeFrom == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_deliveryTime == null && _deliveryCost == null && _deliveryFreeFrom == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: clr.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Center(child: Text("Bezorginformatie niet beschikbaar voor dit product.")),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: clr.primary, size: 22),
              const SizedBox(width: 10),
              Text("Thuisbezorgd", style: txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (_deliveryCost != null && _deliveryCost!.isNotEmpty)
                Text(" $_deliveryCost", style: txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (_deliveryTime != null && _deliveryTime!.isNotEmpty)
            Text("Verwachte bezorging: ${_deliveryTime!}", style: txt.bodyMedium),
          if (_deliveryFreeFrom != null && _deliveryFreeFrom!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(_deliveryFreeFrom!, style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: clr.background,
      appBar: AppBar(
        backgroundColor: clr.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Product Details", style: txt.titleLarge),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductInfoCard(txt, clr),
            const SizedBox(height: 16),
            _buildSpecificationsCard(),
            _buildAvailabilityCard(txt, clr),
            const SizedBox(height: 24),
            if (!_isLoadingDetails && (_description != null || _specifications != null))
              ProductInfoSection(
                isLoadingDetails: _isLoadingDetails,
                description: _description,
                specifications: _specifications,
                detailsError: _detailsError,
              ),
            if (_detailsError != null &&
                _description == null &&
                _specifications == null &&
                !_isLoadingDetails &&
                _productVariants.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _detailsError!,
                    style: TextStyle(color: clr.error),
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