// lib/screens/product_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'dart:convert';
import 'dart:async';

import '../models/product.dart';
import 'scanner_screen.dart';

// Enum voor de bestelstatus van een product.
enum OrderabilityStatus
{
  onlineAndCC,        
  clickAndCollectOnly, 
  outOfAssortment,     
  unknown              
}

// Helper class om de resultaten van de achtergrond HTML parse vast te houden.
class _ProductDetailsScrapeResult
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

  _ProductDetailsScrapeResult(
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

class ProductDetailsScreen extends StatefulWidget
{
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

// Top-level functie die in een aparte isolate draait om de UI thread niet te blokkeren.
// Parset de HTML body van de product detail pagina.
Future<_ProductDetailsScrapeResult> _parseDetailsInBackground(String htmlBody) async
{
  final document = parse(htmlBody);
  String? pDesc;
  String? pSpecs;
  String? fImgUrl;
  String? newPrice;
  String? newOldPrice;
  String? newDiscount;
  String? newPromoDesc;
  String? newPricePerUnit;
  String? newPriceUnit;
  String? newPricePerUnitLabel;
  OrderabilityStatus determinedStatus = OrderabilityStatus.unknown;

  final RegExp priceCleanRegex = RegExp(r'[^\d,.]');
  final RegExp promoDescCleanupRegex1 = RegExp(r'Bekijk alle producten.*$', multiLine: true);
  final RegExp promoDescCleanupRegex2 = RegExp(r'\s+');

  try
  {
    // Bepaal Bestelstatus
    final orderBlock = document.querySelector('#product-order-block');
    if (orderBlock != null)
    {
       final combinedState = orderBlock.attributes['data-combined-state']?.toLowerCase();
       final outOfAssortmentLabel = orderBlock.querySelector('.status-label.yellow');

       if (combinedState == 'outofassortiment' || (outOfAssortmentLabel != null && outOfAssortmentLabel.text.contains('uit ons assortiment')))
       {
          determinedStatus = OrderabilityStatus.outOfAssortment;
       }
       else if (combinedState == 'clickandcollect')
       {
          determinedStatus = OrderabilityStatus.clickAndCollectOnly;
       }
       else
       {
          final onlineLabelGreen = document.querySelector('.status-label.green')?.text.toLowerCase() ?? '';
          final hasHomeDelivery = document.querySelector('.delivery-options .delivery-method')?.text.toLowerCase().contains('thuisbezorgd') ?? false;
          final addToCartButton = document.querySelector('.js-add-to-cart-button')?.text.toLowerCase().trim() ?? '';

          if (onlineLabelGreen.contains('online') || onlineLabelGreen.contains('op voorraad') || hasHomeDelivery || addToCartButton == 'in winkelwagen')
          {
             determinedStatus = OrderabilityStatus.onlineAndCC;
          }
          else if (addToCartButton == 'click & collect')
          {
             determinedStatus = OrderabilityStatus.clickAndCollectOnly;
          }
          else
          {
             determinedStatus = OrderabilityStatus.unknown;
          }
       }
    }
    else
    {
       final outOfAssortmentMain = document.querySelector('main .status-label.yellow');
       if (outOfAssortmentMain != null && outOfAssortmentMain.text.contains('uit ons assortiment'))
       {
         determinedStatus = OrderabilityStatus.outOfAssortment;
       }
       else
       {
         determinedStatus = OrderabilityStatus.unknown;
       }
    }

    // Scrape overige details
    final infoEl = document.querySelector('#product-info-content');
    if (infoEl != null)
    {
      String short = infoEl.querySelectorAll('div.product-info-short ul li').map((li) => '• ${li.text.trim()}').join('\n');
      final descEl = infoEl.querySelector('div.description div[itemprop="description"] p') ?? infoEl.querySelector('div.description p');
      String main = descEl?.text.trim() ?? '';
      List<String> parts = [];
      if (short.isNotEmpty) parts.add(short);
      if (main.isNotEmpty) parts.add(main);
      pDesc = parts.join('\n\n').trim();
      if (pDesc.isEmpty) pDesc = null;
    }

    final specsEl = document.querySelector('#product-specs');
    if (specsEl != null)
    {
      final List<String> lines = [];
      final tables = specsEl.querySelectorAll('table.fancy-table');
      if (tables.isNotEmpty)
      {
        for (var t in tables)
        {
          final h = t.querySelector('thead tr.group-name th strong');
          if (h != null)
          {
            if (lines.isNotEmpty) lines.add('');
            lines.add('${h.text.trim()}:');
          }
          final rows = t.querySelectorAll('tbody tr');
          for (var r in rows)
          {
            final kE = r.querySelector('th.attrib');
            final vE = r.querySelector('td.value .feature-value');
            if (kE != null && vE != null)
            {
              final k = kE.text.trim();
              final v = vE.text.trim();
              if (k.isNotEmpty) lines.add('  $k: $v');
            }
          }
        }
        pSpecs = lines.join('\n').trim();
        if (pSpecs.isEmpty) pSpecs = 'Specificaties leeg.';
      }
      else
      {
        pSpecs = 'Geen specificaties tabel gevonden.';
      }
    }
    else
    {
      pSpecs = 'Specificaties sectie niet gevonden.';
    }

    final imgEl = document.querySelector('img.product-main-image');
    if (imgEl != null)
    {
      String? dS = imgEl.attributes['data-src'];
      String? s = imgEl.attributes['src'];
      String? tmp = dS ?? s;
      if (tmp != null && tmp.contains('/placeholders/'))
      {
        String? alt = (tmp == dS) ? s : dS;
        if (alt != null && !alt.contains('/placeholders/')) { tmp = alt; } else { tmp = null; }
      }
      if (tmp != null && tmp.startsWith('http')) { fImgUrl = tmp; }
    }
    if (fImgUrl == null)
    {
      final metaImg = document.querySelector('meta[itemprop="image"]');
      String? mUrl = metaImg?.attributes['content'];
      if (mUrl != null && mUrl.startsWith('http')) { fImgUrl = mUrl; }
    }

    newPrice = document.querySelector('meta[itemprop="price"]')?.attributes['content']?.trim();
    if (newPrice == null || newPrice.isEmpty)
    {
      final priceElement = document.querySelector('.price-sales-standard .price-amount') ?? document.querySelector('.pdp-price__integer');
      final decimalElement = document.querySelector('.pdp-price__fractional');
      if (priceElement != null && decimalElement == null)
      {
        newPrice = priceElement.text.trim().replaceAll(priceCleanRegex, '').replaceFirst(',', '.');
      }
      else if (priceElement != null && decimalElement != null)
      {
        final intP = priceElement.text.trim();
        final decP = decimalElement.text.trim();
        if (intP.isNotEmpty && decP.isNotEmpty) { newPrice = '$intP.$decP'; }
      }
    }

    newOldPrice = document.querySelector('.product-price-base .before-price')?.text.trim() ?? document.querySelector('.pdp-price__retail .price-amount')?.text.trim() ?? document.querySelector('.price-suggested .price-amount')?.text.trim() ?? document.querySelector('span[data-price-type="oldPrice"] .price')?.text.trim();
    if (newOldPrice != null)
    {
      newOldPrice = newOldPrice.replaceAll(priceCleanRegex, '').replaceFirst(',', '.');
      if (newOldPrice.isEmpty || newOldPrice == newPrice) { newOldPrice = null; }
    }

    newPriceUnit = document.querySelector('.pdp-price__unit')?.text.trim() ?? document.querySelector('.product-tile-price-unit')?.text.trim();
    if (newPriceUnit != null)
    {
      newPriceUnit = newPriceUnit.replaceAll('m²', 'm2');
      if (newPriceUnit.isEmpty) newPriceUnit = null;
    }

    final pricePerUnitContainer = document.querySelector('.product-price-per-unit');
    if (pricePerUnitContainer != null)
    {
      final pricePerUnitElement = pricePerUnitContainer.querySelector('span:last-child');
      if (pricePerUnitElement != null)
      {
        newPricePerUnit = pricePerUnitElement.text.trim().replaceAll(priceCleanRegex, '').replaceFirst(',', '.');
        if (newPricePerUnit.isEmpty || newPricePerUnit == newPrice) newPricePerUnit = null;
      }
      final pricePerUnitLabelElement = pricePerUnitContainer.querySelector('span:first-child');
      if (pricePerUnitLabelElement != null)
      {
        newPricePerUnitLabel = pricePerUnitLabelElement.text.trim();
        if (newPricePerUnitLabel.isEmpty) newPricePerUnitLabel = null;
      }
    }

    final promoInfoLabel = document.querySelector('.promotion-info-label div div');
    if (promoInfoLabel != null)
    {
      newDiscount = promoInfoLabel.text.trim();
    }
    else
    {
      newDiscount = document.querySelector('.product-labels .label-item')?.text.trim() ?? document.querySelector('.sticker-action')?.text.trim() ?? document.querySelector('.product-badge .badge-text')?.text.trim();
    }
    if (newDiscount != null && newDiscount.isEmpty) newDiscount = null;
    if (newDiscount == null && newOldPrice != null && newPrice != null && newOldPrice != newPrice)
    {
      newDiscount = "Actie";
    }

    final promoDescElement = document.querySelector('dd.promotion-info-description');
    if (promoDescElement != null)
    {
      newPromoDesc = promoDescElement.text.trim()
        .replaceAll(promoDescCleanupRegex1, '')
        .replaceAll(promoDescCleanupRegex2, ' ')
        .trim();
      if (newPromoDesc.isEmpty) newPromoDesc = null;
    }
  }
  catch (e, s)
  {
    print("Error during background parsing: $e\n$s");
    // Return met de status die we eventueel wel vonden, en de rest null
    return _ProductDetailsScrapeResult(status: determinedStatus);
  }

  return _ProductDetailsScrapeResult(
    status: determinedStatus,
    description: pDesc,
    specifications: pSpecs,
    imageUrl: fImgUrl,
    priceString: newPrice,
    oldPriceString: newOldPrice,
    priceUnit: newPriceUnit,
    pricePerUnitString: newPricePerUnit,
    pricePerUnitLabel: newPricePerUnitLabel,
    discountLabel: newDiscount,
    promotionDescription: newPromoDesc
  );
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
  static const String _gammaCookieValueHaarlem = '39'; // Gebruik Haarlem als default voor Gamma API
  final RegExp _ean13Regex = RegExp(r'^[0-9]{13}$');

  @override
  void initState()
  {
    super.initState();
    // Initialiseer state met data van het meegegeven Product object
    _detailImageUrl = widget.product.imageUrl;
    _detailPriceString = widget.product.priceString;
    _detailOldPriceString = widget.product.oldPriceString;
    _detailDiscountLabel = widget.product.discountLabel;
    _detailPromotionDescription = widget.product.promotionDescription;
    _detailPricePerUnitString = widget.product.pricePerUnitString;
    _detailPriceUnit = widget.product.priceUnit?.replaceAll('m²', 'm2'); // Vervang m² direct
    _detailPricePerUnitLabel = widget.product.pricePerUnitLabel;

    _fetchProductDetails();
    _fetchSpecificStoreStocks();
  }

  @override
  void dispose()
  {
     super.dispose();
  }

  // Haalt de HTML van de productpagina op en start de background parse.
  Future<void> _fetchProductDetails() async
  {
    setState(()
    {
      _isLoadingDetails = true;
      _detailsError = null;
      _orderStatus = OrderabilityStatus.unknown; // Reset status bij opnieuw laden
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
    print('[Parser Details] Fetching URL: $url');

    try
    {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;

      if (response.statusCode == 200)
      {
        final responseBody = utf8.decode(response.bodyBytes);
        // Start de parse op een aparte isolate
        final result = await compute(_parseDetailsInBackground, responseBody);
        if (!mounted) return;

        // Update de state met de resultaten van de parse
        setState(()
        {
          _description = result.description ?? _description;
          _specifications = result.specifications ?? _specifications;
          // Update image URL niet meer, gebruik de originele van de lijst
          // _detailImageUrl = result.imageUrl ?? _detailImageUrl;
          _detailPriceString = result.priceString ?? _detailPriceString;
          _detailOldPriceString = result.oldPriceString ?? _detailOldPriceString;
          _detailPriceUnit = result.priceUnit ?? _detailPriceUnit;
          _detailPricePerUnitString = result.pricePerUnitString ?? _detailPricePerUnitString;
          _detailPricePerUnitLabel = result.pricePerUnitLabel ?? _detailPricePerUnitLabel;
          _detailDiscountLabel = result.discountLabel ?? _detailDiscountLabel;
          _detailPromotionDescription = result.promotionDescription ?? _detailPromotionDescription;
          _orderStatus = result.status; // Update de bestelstatus

          // Check of er überhaupt iets nuttigs is gevonden
          if (_description == null && _specifications == null && result.priceString == null)
          {
            _detailsError = 'Kon geen details uit de productpagina lezen.';
          }
          else
          {
            _detailsError = null; // Reset error als er wel iets gevonden is
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
    catch (e, s)
    {
      print('[Parser Details] Exception: $e\n$s');
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
        setState(() { _isLoadingDetails = false; });
      }
    }
  }

  // Haalt de voorraad op voor de gespecificeerde winkels via de Gamma/Karwei API.
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
      // Probeer artikelcode naar int te parsen voor zekerheid
      try { productId = int.parse(productId).toString(); } catch (e) {}

      Map<String, int?> finalStocks = {};
      List<String> errors = [];

      final gammaEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma'));
      final karweiEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei'));

      // Helper functie om API response te parsen
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
              if (quantity is int) { targetStockMap[storeName] = quantity; }
              else if (quantity is String) { targetStockMap[storeName] = int.tryParse(quantity); }
              else { targetStockMap[storeName] = null; } // Onbekend type
            }
            else
            {
              targetStockMap[storeName] = null; // Niet gevonden in response (niet in assortiment?)
            }
          }
        }
        catch (e)
        {
          print("$brand Stock Parse Error: $e");
          errors.add('$brand parse');
        }
      }

      // Fetch Gamma stock
      if (gammaEntries.isNotEmpty)
      {
        final gammaParam = gammaEntries.map((e) => 'Stock-${e.value}-$productId').join(',');
        final gammaUrl = Uri.parse('$_gammaStockApiBase?uids=$gammaParam');
        final gammaHeaders =
        {
          'User-Agent': _userAgent,
          'Origin': 'https://www.gamma.nl',
          'Referer': 'https://www.gamma.nl/',
          'Cookie': '$_gammaCookieName=$_gammaCookieValueHaarlem' // Nodig voor Gamma API
        };
        try
        {
          print("Fetching Gamma stock: $gammaUrl");
          final response = await http.get(gammaUrl, headers: gammaHeaders);
          if (response.statusCode == 200)
          {
            parseStockResponse(response.body, gammaEntries, finalStocks, "Gamma");
          }
          else
          {
            print("Gamma Stock API Error: ${response.statusCode}");
            errors.add('G-${response.statusCode}');
            for (var entry in gammaEntries) { finalStocks[entry.key] = null; } // Markeer als onbekend bij API fout
          }
        }
        catch (e)
        {
          print("Gamma Stock Network Error: $e");
          errors.add('G-Net');
          for (var entry in gammaEntries) { finalStocks[entry.key] = null; } // Markeer als onbekend bij netwerkfout
        }
      }

      // Fetch Karwei stock
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
          print("Fetching Karwei stock: $karweiUrl");
          final response = await http.get(karweiUrl, headers: karweiHeaders);
          if (response.statusCode == 200)
          {
            parseStockResponse(response.body, karweiEntries, finalStocks, "Karwei");
          }
          else
          {
            print("Karwei Stock API Error: ${response.statusCode}");
            errors.add('K-${response.statusCode}');
            for (var entry in karweiEntries) { finalStocks[entry.key] = null; }
          }
        }
        catch (e)
        {
          print("Karwei Stock Network Error: $e");
          errors.add('K-Net');
          for (var entry in karweiEntries) { finalStocks[entry.key] = null; }
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

  // Navigeert naar de scanner en geeft het resultaat terug aan de HomePage.
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
        print("[Details Nav] Scan resultaat: $scanResult");
        String? resultValueForHomePage;
        final Uri? uri = Uri.tryParse(scanResult);
        final bool isLikelyUrl = uri != null && uri.hasScheme && uri.hasAuthority;
        final bool isGammaProductUrl = isLikelyUrl && uri.host.contains('gamma.nl') && uri.pathSegments.contains('assortiment') && uri.pathSegments.length > 1 && uri.pathSegments.last.isNotEmpty;
        final bool isEan13 = _ean13Regex.hasMatch(scanResult);

        if (isGammaProductUrl)
        {
          print("[Details Nav] Gamma URL gedetecteerd.");
          String pIdRaw = uri.pathSegments.last;
          String sId = pIdRaw;
          if (pIdRaw.isNotEmpty && (pIdRaw.startsWith('B') || pIdRaw.startsWith('b')) && pIdRaw.length > 1)
          {
            sId = pIdRaw.substring(1);
            print("[Details Nav] Gefilterde ID: $sId");
          }
          else { print("[Details Nav] Geëxtraheerde ID (geen B): $sId"); }
          try { sId = int.parse(sId).toString(); print("[Details Nav] Opgeschoonde ID: $sId"); }
          catch(e) { print("[Details Nav] Int parse mislukt, gebruik ruwe ID (na B filter): $sId. Fout: $e"); }
          resultValueForHomePage = sId;
        }
        else if (isEan13)
        {
          print("[Details Nav] EAN13 gedetecteerd.");
          resultValueForHomePage = scanResult;
        }
        else
        {
          print("[Details Nav] Onbekend formaat.");
          resultValueForHomePage = scanResult;
          if(mounted)
          {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Onbekend code formaat gescand: $scanResult')),
            );
          }
        }

        // Geef het resultaat (artikel ID of EAN) terug aan de vorige pagina (HomePage)
        if (mounted && resultValueForHomePage != null)
        {
          Navigator.pop(context, resultValueForHomePage);
        }
      }
      else
      {
        print("Scanner gesloten zonder resultaat.");
      }
    }
    catch (e)
    {
      if (!mounted) return;
      print("Scanner Error on details screen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij openen scanner: $e')),
      );
    }
  }

  // Toont een dialoog met de promotie details.
  void _showPromotionDetails(BuildContext context)
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

  @override
  Widget build(BuildContext context)
  {
    final txt = Theme.of(context).textTheme;
    final clr = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isDiscountTappable = _detailPromotionDescription != null && _detailPromotionDescription!.isNotEmpty;

    return Scaffold(
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
          [
            // Afbeelding
            if (_detailImageUrl != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      _detailImageUrl!,
                      height: 250,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, p) => (p == null)
                        ? child
                        : Container(height: 250, alignment: Alignment.center, child: CircularProgressIndicator(value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null)),
                      errorBuilder: (ctx, err, st) => Container(height: 250, color: clr.surfaceContainerHighest.withAlpha(60), alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, size: 80, color: Colors.grey[500])),
                    ),
                  ),
                ),
              )
            else // Placeholder als geen afbeelding
              Container(height: 250, color: clr.surfaceContainerHighest.withAlpha(60), alignment: Alignment.center, child: Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey[500])),

            // Titel en Codes
            Text(widget.product.title, style: txt.headlineSmall),
            const SizedBox(height: 8),
            Row(
              children:
              [
                Icon(Icons.inventory_2_outlined, size: 16, color: txt.bodySmall?.color),
                const SizedBox(width: 4),
                Text('Art: ${widget.product.articleCode}', style: txt.bodyLarge),
                const SizedBox(width: 16),
                if (widget.product.eanCode != null) ...
                [
                  Icon(Icons.barcode_reader, size: 16, color: txt.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(widget.product.eanCode!, style: txt.bodyMedium?.copyWith(color: txt.bodySmall?.color)),
                ],
              ],
            ),

            // Bestelstatus Chip
            if (!_isLoadingDetails)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                child: _buildOrderStatusChip(_orderStatus, txt, clr),
              ),

            const SizedBox(height: 16),

            // Prijs en Korting
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children:
              [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                    [
                      if (_isLoadingDetails && _detailPriceString == null)
                        Text("Prijs laden...", style: txt.headlineSmall?.copyWith(color: Colors.grey[600]))
                      else if (_detailPriceString != null)
                        RichText(
                          text: TextSpan(
                            style: txt.headlineSmall?.copyWith(color: clr.onSurface),
                            children:
                            [
                              if (_detailOldPriceString != null && _detailOldPriceString != _detailPriceString)
                                TextSpan(
                                  text: '€ $_detailOldPriceString  ',
                                  style: TextStyle(
                                    fontSize: txt.titleMedium?.fontSize ?? 16,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              TextSpan(
                                text: '€ $_detailPriceString',
                                style: TextStyle(
                                  color: clr.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_detailPriceUnit != null)
                                TextSpan(
                                  text: ' ${(_detailPriceUnit)}',
                                  style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant, fontWeight: FontWeight.normal)
                                )
                            ],
                          ),
                        )
                      else
                        Text('Prijs onbekend', style: txt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600])),

                      if (_detailPricePerUnitString != null && _detailPricePerUnitString != _detailPriceString)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '€ $_detailPricePerUnitString ${(_detailPricePerUnitLabel ?? "p/eenheid").toLowerCase()}',
                            style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Kortingslabel (indien aanwezig)
                if (_detailDiscountLabel != null)
                  Tooltip(
                    message: isDiscountTappable ? "Bekijk actie details" : "",
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isDiscountTappable ? () => _showPromotionDetails(context) : null,
                        borderRadius: BorderRadius.circular(6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.orange[700] : clr.primary,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children:
                            [
                              Text(
                                _detailDiscountLabel!,
                                style: txt.labelMedium?.copyWith(
                                  color: isDarkMode ? Colors.white : clr.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isDiscountTappable)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: (txt.labelMedium?.fontSize ?? 14.0) + 2,
                                    color: (isDarkMode ? Colors.white : clr.onPrimary).withOpacity(0.8),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(thickness: 0.5),

            // Voorraad Sectie
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text('Voorraad (indicatie)', style: txt.titleLarge?.copyWith(fontSize: 18)),
            ),
            _buildStoreStockSection(context, txt),

            const Divider(height: 32, thickness: 0.5),

            // Omschrijving & Specificaties Sectie
            _buildDetailsSection(context, txt),

            // Toon details error alleen als er geen beschrijving/specs zijn geladen
            if (_detailsError != null && _description == null && _specifications == null && !_isLoadingDetails)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    _detailsError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  )
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Bouwt de chip die de bestelstatus toont.
  Widget _buildOrderStatusChip(OrderabilityStatus status, TextTheme textTheme, ColorScheme colorScheme)
  {
    IconData iconData;
    Color chipColor;
    Color contentColor;
    String label;

    switch (status)
    {
      case OrderabilityStatus.onlineAndCC:
        iconData = Icons.local_shipping_outlined;
        chipColor = Colors.green[100]!;
        contentColor = Colors.green[800]!;
        label = "Online & Click/Collect";
        break;
      case OrderabilityStatus.clickAndCollectOnly:
        iconData = Icons.store_mall_directory_outlined;
        chipColor = Colors.blue[100]!;
        contentColor = Colors.blue[800]!;
        label = "Alleen Click & Collect";
        break;
      case OrderabilityStatus.outOfAssortment:
        iconData = Icons.highlight_off_outlined;
        chipColor = Colors.red[100]!;
        contentColor = Colors.red[800]!;
        label = "Uit assortiment";
        break;
      case OrderabilityStatus.unknown:
      default:
        iconData = Icons.help_outline;
        chipColor = Colors.grey[300]!;
        contentColor = Colors.grey[700]!;
        label = "Bestelstatus onbekend";
        break;
    }

    return Chip(
      avatar: Icon(iconData, size: 18, color: contentColor),
      label: Text(label, style: textTheme.bodyMedium?.copyWith(color: contentColor, fontWeight: FontWeight.w500)),
      backgroundColor: chipColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // Bouwt de lijst met winkelvoorraden.
  Widget _buildStoreStockSection(BuildContext context, TextTheme textTheme)
  {
    if (_isLoadingStock)
    {
      return const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2.0)));
    }

    List<Widget> children = [];

    if (_stockError != null)
    {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            _stockError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        )
      );
    }

    if (_storeStocks.isEmpty && _stockError == null)
    {
      children.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              "Kon voorraad voor geen enkele winkel vinden.",
              style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        )
      );
    }
    else
    {
      // Sorteer: Haarlem eerst, dan Gamma, dan Karwei, dan alfabetisch
      final sortedEntries = _storeStocks.entries.toList()
        ..sort((a, b)
        {
          bool aIsHaarlem = a.key == 'Gamma Haarlem';
          bool bIsHaarlem = b.key == 'Gamma Haarlem';
          if (aIsHaarlem != bIsHaarlem) return aIsHaarlem ? -1 : 1;

          bool aIsGamma = a.key.startsWith('Gamma');
          bool bIsGamma = b.key.startsWith('Gamma');
          if (aIsGamma != bIsGamma) return aIsGamma ? -1 : 1;

          return a.key.compareTo(b.key);
        });

      for (var entry in sortedEntries)
      {
        final storeName = entry.key;
        final stockCount = entry.value;
        final isHaarlem = storeName == 'Gamma Haarlem';

        IconData icon;
        Color color;
        String text;

        if (stockCount == null)
        {
          icon = Icons.help_outline;
          color = Colors.grey;
          text = "Niet in assortiment?";
        }
        else if (stockCount > 5)
        {
          icon = Icons.check_circle_outline;
          color = Colors.green[700]!;
          text = "$stockCount stuks";
        }
        else if (stockCount > 0)
        {
          icon = Icons.warning_amber_outlined;
          color = Colors.orange[700]!;
          text = "$stockCount stuks (laag)";
        }
        else
        {
          icon = Icons.cancel_outlined;
          color = Theme.of(context).colorScheme.error;
          text = "Niet op voorraad";
        }

        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children:
              [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    storeName,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: isHaarlem ? FontWeight.bold : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  )
                ),
                Text(text, style: textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // Bouwt de sectie met productomschrijving en specificaties.
  Widget _buildDetailsSection(BuildContext context, TextTheme textTheme)
  {
    final clr = Theme.of(context).colorScheme;
    final bool hasDescription = _description != null && _description!.isNotEmpty;
    final bool hasSpecs = _specifications != null && !_specifications!.contains('niet gevonden') && !_specifications!.contains('leeg') && _specifications!.isNotEmpty;

    if (_isLoadingDetails)
    {
      return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(), ));
    }

    // Als er een error is en GEEN beschrijving/specs, toon niets (error wordt elders getoond)
    if (_detailsError != null && !hasDescription && !hasSpecs && !_isLoadingDetails)
    {
      return const SizedBox.shrink();
    }
    else
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
        [
          // Toon error bovenaan als er wel beschrijving/specs zijn maar ook een error was
          if(_detailsError != null && (hasDescription || hasSpecs))
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text("Let op: $_detailsError", style: TextStyle(color: Colors.orange[800], fontStyle: FontStyle.italic)),
            ),

          // Omschrijving
          if (hasDescription) ...
          [
            Text('Omschrijving', style: textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            SelectableText(_description!, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 24),
          ]
          else if (!_isLoadingDetails) ... // Toon alleen 'niet gevonden' als laden klaar is
          [
            Text('Omschrijving niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600])),
            const SizedBox(height: 24),
          ],

          // Divider tussen omschrijving en specs
          if (hasDescription && hasSpecs) ...
          [
            const Divider(thickness: 0.5),
            const SizedBox(height: 24),
          ],

          // Specificaties
          if (hasSpecs) ...
          [
            Text('Specificaties', style: textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: clr.surfaceContainerHighest.withAlpha(40), // Lichte achtergrond
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: clr.outlineVariant.withOpacity(0.3), width: 0.5)
              ),
              child: SelectableText(
                _specifications!,
                style: textTheme.bodyMedium?.copyWith(height: 1.6, fontFamily: 'monospace'), // Monospace voor specs
              )
            ),
            const SizedBox(height: 24),
          ]
          else if (!_isLoadingDetails) ... // Toon alleen 'niet gevonden' als laden klaar is
          [
            // Voeg divider toe als er wel een omschrijving was
            if (hasDescription) ...
            [
              const Divider(thickness: 0.5),
              const SizedBox(height: 24),
            ],
            Text('Specificaties niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600])),
            const SizedBox(height: 24),
          ],
        ],
      );
    }
  }
}