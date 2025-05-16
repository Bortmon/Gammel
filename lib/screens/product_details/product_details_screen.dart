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


class ProductDetailsScreen extends StatefulWidget
{
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
{
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
    _detailImageUrl = widget.product.imageUrl;
    _detailPriceString = widget.product.priceString;
    _detailOldPriceString = widget.product.oldPriceString;
    _detailDiscountLabel = widget.product.discountLabel;
    _detailPromotionDescription = widget.product.promotionDescription;
    _detailPricePerUnitString = widget.product.pricePerUnitString;
    _detailPriceUnit = widget.product.priceUnit?.replaceAll('m²', 'm2');
    _detailPricePerUnitLabel = widget.product.pricePerUnitLabel;

    _fetchProductDetails();
    _fetchSpecificStoreStocks();
  }

  Future<void> _fetchProductDetails() async
  {
    setState(()
    {
      _isLoadingDetails = true;
      _detailsError = null;
      _orderStatus = OrderabilityStatus.unknown;
    });

    if (widget.product.productUrl == null || widget.product.productUrl!.isEmpty)
    {
      if (mounted)
      {
        setState(()
        {
          _detailsError = "Product URL ontbreekt.";
          _isLoadingDetails = false;
          _orderStatus = OrderabilityStatus.unknown;
        });
      }
      return;
    }

    final url = Uri.parse(widget.product.productUrl!);

    try
    {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;

      if (response.statusCode == 200)
      {
        final responseBody = utf8.decode(response.bodyBytes);
        final result = await compute(parseProductDetailsHtml, responseBody);
        if (!mounted) return;

        setState(()
        {
          _description = result.description ?? _description;
          _specifications = result.specifications ?? _specifications;
          _detailPriceString = result.priceString ?? _detailPriceString;
          _detailOldPriceString = result.oldPriceString ?? _detailOldPriceString;
          _detailPriceUnit = result.priceUnit ?? _detailPriceUnit;
          _detailPricePerUnitString = result.pricePerUnitString ?? _detailPricePerUnitString;
          _detailPricePerUnitLabel = result.pricePerUnitLabel ?? _detailPricePerUnitLabel;
          _detailDiscountLabel = result.discountLabel ?? _detailDiscountLabel;
          _detailPromotionDescription = result.promotionDescription ?? _detailPromotionDescription;
          _orderStatus = result.status;

          if (_description == null && _specifications == null && result.priceString == null)
          {
            _detailsError = 'Kon geen details uit de productpagina lezen.';
          }
          else
          {
            _detailsError = null;
          }
        });
      }
      else
      {
        if (mounted)
        {
          setState(()
          {
            _detailsError = 'Fout bij laden details: Server status ${response.statusCode}';
            _orderStatus = OrderabilityStatus.unknown;
          });
        }
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(()
        {
          _detailsError = 'Fout bij verwerken productpagina: $e';
          _orderStatus = OrderabilityStatus.unknown;
        });
      }
    }
    finally
    {
      if (mounted)
      {
        setState(()
        {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _fetchSpecificStoreStocks() async
  {
    setState(()
    {
      _isLoadingStock = true;
      _stockError = null;
      _storeStocks = {};
    });

    String productId = widget.product.articleCode;
    if (productId == 'Code?' || productId == 'Code niet gevonden')
    {
      if (mounted)
      {
        setState(()
        {
          _stockError = "Artikelcode onbekend, kan voorraad niet ophalen.";
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
        // Blijf bij de originele string als parsen mislukt
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

  Future<void> _navigateToScannerFromDetails() async
  {
    try
    {
      final String? scanResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const ScannerScreen()),
      );

      if (!mounted) return;

      if (scanResult != null && scanResult.isNotEmpty)
      {
        String? resultValueForHomePage;
        final Uri? uri = Uri.tryParse(scanResult);
        final bool isLikelyUrl = uri != null && uri.hasScheme && uri.hasAuthority;
        final bool isGammaProductUrl = isLikelyUrl && uri.host.contains('gamma.nl') && uri.pathSegments.contains('assortiment') && uri.pathSegments.length > 1 && uri.pathSegments.last.isNotEmpty;
        final bool isEan13 = _ean13Regex.hasMatch(scanResult);

        if (isGammaProductUrl)
        {
          String pIdRaw = uri.pathSegments.last;
          String sId = pIdRaw;
          if (pIdRaw.isNotEmpty && (pIdRaw.startsWith('B') || pIdRaw.startsWith('b')) && pIdRaw.length > 1)
          {
            sId = pIdRaw.substring(1);
          }
          try
          {
              sId = int.parse(sId).toString();
          }
          catch(e)
          {
              // Blijf bij de originele string als parsen mislukt
          }
          resultValueForHomePage = sId;
        }
        else if (isEan13)
        {
          resultValueForHomePage = scanResult;
        }
        else
        {
          resultValueForHomePage = scanResult;
          if(mounted)
          {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Onbekend code formaat gescand: $scanResult')),
            );
          }
        }

        if (mounted && resultValueForHomePage != null)
        {
          Navigator.pop(context, resultValueForHomePage);
        }
      }
    }
    catch (e)
    {
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

    @override
  Widget build(BuildContext context)
  {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: clr.background, // Explicitly set background for contrast with section containers
      appBar: AppBar(
        title: Text(widget.product.title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
        actions:
        [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: _navigateToScannerFromDetails,
            tooltip: 'Scan nieuwe code',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16.0, bottom: 24.0), // Verticale padding voor de hele scrollview
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
          [
            ProductImageHeader(
              product: widget.product,
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

            const SizedBox(height: 28), // Iets meer ruimte naar de eerste 'grote' sectie

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Voorraad (indicatie)', style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: txt.headlineSmall?.color)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Horizontale padding voor de sectie
              child: ProductStockList(
                isLoadingStock: _isLoadingStock,
                stockError: _stockError,
                storeStocks: _storeStocks,
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Horizontale padding voor de sectie
              child: ProductInfoSection(
                isLoadingDetails: _isLoadingDetails,
                description: _description,
                specifications: _specifications,
                detailsError: _detailsError,
              ),
            ),

            if (_detailsError != null && _description == null && _specifications == null && !_isLoadingDetails)
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
    );
  }
}