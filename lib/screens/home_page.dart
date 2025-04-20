// lib/screens/home_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'dart:async'; // Voor Future.delayed

import '../models/login_result.dart';
import '../models/product.dart'; // Gebruik bijgewerkt model
import 'product_details_screen.dart';
import 'schedule_screen.dart';
import 'scanner_screen.dart';

class HomePage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final VoidCallback onThemeModeChanged;
  final bool isLoggedIn;
  final String? authToken;
  final String? employeeId;
  final String? nodeId;
  final String? userName;
  final Future<LoginResult> Function(BuildContext context) loginCallback;
  final Future<void> Function() logoutCallback;

  const HomePage({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.isLoggedIn,
    required this.authToken,
    required this.employeeId,
    required this.nodeId,
    required this.userName,
    required this.loginCallback,
    required this.logoutCallback,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  String _lastSearchTerm = '';
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() { setState(() {}); });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToScanner() async {
    try {
      final String? scanResult = await Navigator.push<String>( context, MaterialPageRoute(builder: (context) => const ScannerScreen()), );
      if (!mounted) return;
      if (scanResult != null && scanResult.isNotEmpty) {
        print("[Navigation] Scan resultaat ontvangen: $scanResult");
        final Uri? uri = Uri.tryParse(scanResult);
        final bool isLikelyUrl = uri != null && uri.hasScheme && uri.hasAuthority;
        final bool isGammaProductUrl = isLikelyUrl && uri.host.endsWith('gamma.nl') && uri.pathSegments.contains('assortiment') && uri.pathSegments.contains('p') && uri.pathSegments.last.isNotEmpty;
        final bool isEan13 = RegExp(r'^[0-9]{13}$').hasMatch(scanResult);

        if (isGammaProductUrl) {
           print("[Navigation] Gamma Product URL gescand: $scanResult");
           String productIdRaw = uri.pathSegments.last; String searchId = productIdRaw;
           if (productIdRaw.isNotEmpty && (productIdRaw.startsWith('B') || productIdRaw.startsWith('b')) && productIdRaw.length > 1) { searchId = productIdRaw.substring(1); print("[Navigation] Geëxtraheerde en gefilterde Product ID: $searchId"); }
           else { print("[Navigation] Geëxtraheerde Product ID (geen 'B' gefilterd): $searchId"); }
           try { searchId = int.parse(searchId).toString(); print("[Navigation] Opgeschoonde ID voor zoeken: $searchId"); }
           catch(e) { print("[Navigation] Kon ID '$searchId' niet naar int parsen, gebruik origineel (na B filter)."); }
           _searchController.text = searchId; _searchProducts(searchId);
        } else if (isEan13) {
           print("[Navigation] EAN13 gescand: $scanResult. Start zoekopdracht...");
           _searchController.text = scanResult; _searchProducts(scanResult);
        } else {
           print("[Navigation] Onbekend scan resultaat formaat: $scanResult");
           _searchController.text = scanResult;
           ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Onbekend code formaat gescand: $scanResult')), );
           setState(() { _products = []; _error = null; });
        }
      } else { print("Scanner gesloten zonder resultaat."); }
    } catch (e) { if (!mounted) return; setState(() { _error = "Fout scanner: $e"; _isLoading = false; }); }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) return; FocusScope.of(context).unfocus(); setState(() { _isLoading = true; _error = null; _products = []; _lastSearchTerm = query; });
    final url = Uri.parse('https://www.gamma.nl/assortiment/zoeken?text=${Uri.encodeComponent(query)}');
    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final document = parse(response.body);
        final List<Product> foundProducts = _parseProducts(document);
        setState(() { _products = foundProducts; if (_products.isEmpty && _lastSearchTerm.isNotEmpty) { _error = 'Geen producten gevonden voor "$_lastSearchTerm".'; } _isLoading = false; });
      } else { setState(() { _error = 'Fout: Status ${response.statusCode}'; _isLoading = false; }); }
    } catch (e) { print('Error search results: $e'); if (!mounted) return; setState(() { _error = 'Fout: $e'; _isLoading = false; }); }
  }

  // --- PARSER UITGEBREID MET PRIJS PER STUK ---
  List<Product> _parseProducts(dom.Document document) {
    final products = <Product>[];
    final productElements = document.querySelectorAll('article.js-product-tile');
    print("[Parser] Found ${productElements.length} product tiles.");

    for (final element in productElements) {
      String? imageUrl; String? priceString; String? oldPriceString; String? discountLabel;
      String? title = 'Titel?'; String? articleCode = 'Code?'; String? eanCode; String? productUrl;
      String? promotionDescription;
      String? pricePerUnitString; // Nieuwe variabele

      try {
        // Basis Info
        title = element.querySelector('div.product-tile-name a')?.text.trim() ?? element.querySelector('a.click-mask')?.attributes['title']?.trim() ?? 'Titel?';
        productUrl = element.querySelector('a.click-mask')?.attributes['href'];
        if (productUrl != null && !productUrl.startsWith('http')) { if (!productUrl.startsWith('/')) { productUrl = '/$productUrl'; } productUrl = 'https://www.gamma.nl$productUrl'; }
        articleCode = element.attributes['data-objectid']?.trim();
        if (articleCode != null && articleCode.isNotEmpty && articleCode.length > 1) { if (int.tryParse(articleCode.substring(0, 1)) == null) { articleCode = articleCode.substring(1); } }
        eanCode = element.attributes['data-ean']?.trim();
        if (articleCode == null || articleCode.isEmpty) { articleCode = eanCode ?? 'Code?'; eanCode = null; }
        else if (eanCode == null || eanCode.isEmpty) { eanCode = null; }

        // Afbeelding
        final imageContainer = element.querySelector('div.product-tile-image');
        if (imageContainer != null) {
          final imageElement = imageContainer.querySelector('img:not(.sticker)');
          if (imageElement != null) { imageUrl = imageElement.attributes['data-src'] ?? imageElement.attributes['src']; }
          else { final fallbackImageElement = imageContainer.querySelector('img'); imageUrl = fallbackImageElement?.attributes['data-src'] ?? fallbackImageElement?.attributes['src']; }
          if (imageUrl != null && !imageUrl.startsWith('http')) imageUrl = null;
        }

        // Prijs & Korting Parsing
        final priceContainer = element.querySelector('.product-price-container');
        if (priceContainer != null) {
             // Huidige prijs (vaak per m2)
             final priceElement = priceContainer.querySelector('.product-tile-price .product-tile-price-current');
             final decimalElement = priceContainer.querySelector('.product-tile-price .product-tile-price-decimal');
             if (priceElement != null && decimalElement != null) {
                String intPart = priceElement.text.trim().replaceAll('.', ''); String decPart = decimalElement.text.trim();
                if (intPart.isNotEmpty && decPart.isNotEmpty) { priceString = '$intPart.$decPart'; }
             }
             if (priceString == null) { priceString = element.attributes['data-price']?.trim(); }

             // Oude prijs (vaak per m2)
             final oldPriceElem = priceContainer.querySelector('.product-tile-price-old .before-price') ?? priceContainer.querySelector('.product-tile-price-old span.before-price') ?? priceContainer.querySelector('span.product-tile-price-old');
             if (oldPriceElem != null) {
                 oldPriceString = oldPriceElem.text.trim().replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.');
                 if (oldPriceString.isEmpty || oldPriceString == priceString) { oldPriceString = null; }
             }

             // Prijs per eenheid
             final pricePerUnitElement = priceContainer.querySelector('.product-price-per-unit span:last-child');
             if (pricePerUnitElement != null) {
                pricePerUnitString = pricePerUnitElement.text.trim().replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.');
                if (pricePerUnitString.isEmpty) pricePerUnitString = null;
             }

             // Discount label
             discountLabel = priceContainer.querySelector('.promotion-text-label')?.text.trim();
             if (discountLabel == null || discountLabel.isEmpty) { final sticker = element.querySelector('span.sticker.promo, img.sticker.promo'); if (sticker != null) { discountLabel = sticker.attributes['alt']?.trim(); } }
             if (discountLabel == null || discountLabel.isEmpty) { final badge = element.querySelector('.product-tile-badge'); if (badge != null) { discountLabel = badge.text.trim();} }
             if (discountLabel == null || discountLabel.isEmpty) { final loyaltyLabel = priceContainer.querySelector('div.product-loyalty-label') ?? element.querySelector('dt.product-loyalty-label'); if (loyaltyLabel != null && loyaltyLabel.text.contains("Voordeelpas")) { discountLabel = "Voordeelpas"; final promoLabelDiv = element.querySelector('dt.promotion-info-label div div'); if (promoLabelDiv != null) { String promoText = promoLabelDiv.text.trim(); if(promoText.isNotEmpty) discountLabel = promoText; } } }
             if (discountLabel == null && oldPriceString != null && priceString != null && oldPriceString != priceString) { discountLabel = "Actie"; }

             // Promotion Description (vaak verborgen)
             final promoDescElement = priceContainer.querySelector('.promotion-info-description') ?? element.querySelector('dd.promotion-info-description');
             if (promoDescElement != null) { promotionDescription = promoDescElement.text.trim().replaceAll(RegExp(r'Bekijk alle producten.*$', multiLine: true), '').replaceAll(RegExp(r'\s+'), ' ').trim(); if (promotionDescription.isEmpty) promotionDescription = null; }

        } else { priceString = element.attributes['data-price']?.trim(); print("[Parser] Price container not found for: $title"); }
        if (discountLabel != null && discountLabel.isEmpty) discountLabel = null;


        if (title != 'Titel?' && articleCode != 'Code?') {
          products.add(Product(
            title: title, articleCode: articleCode, eanCode: eanCode, imageUrl: imageUrl,
            productUrl: productUrl, priceString: priceString,
            oldPriceString: oldPriceString, discountLabel: discountLabel,
            promotionDescription: promotionDescription,
            pricePerUnitString: pricePerUnitString, // Meegeven
          ));
        }
      } catch (e, s) { print("[Parser Results] Error parsing product: $e\nStack: $s"); }
    }
    print("[Parser] Parsed ${products.length} products.");
    return products;
  }

  Future<void> _navigateToDetails(BuildContext context, Product product) async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product),),);
    if (mounted && result != null && result.isNotEmpty) { print("[Nav] Barcode '$result' from details."); _searchController.text = result; _searchProducts(result); }
  }

  void _navigateToScheduleScreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleScreen(
          authToken: widget.authToken, isLoggedIn: widget.isLoggedIn, employeeId: widget.employeeId, nodeId: widget.nodeId, userName: widget.userName,
          loginCallback: widget.loginCallback, logoutCallback: widget.logoutCallback,
        ),),);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final IconData themeIcon = isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gammel'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_outlined), tooltip: 'Bekijk rooster', onPressed: () => _navigateToScheduleScreen(context),),
          IconButton(icon: Icon(themeIcon), tooltip: isDark ? 'Licht' : 'Donker', onPressed: widget.onThemeModeChanged,),
          IconButton(icon: const Icon(Icons.qr_code_scanner_outlined), onPressed: () => _navigateToScanner(), tooltip: 'Scan Barcode',),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
        child: Column(children: [
            TextField(controller: _searchController, decoration: InputDecoration(labelText: 'Zoek product of scan barcode', prefixIcon: const Icon(Icons.search), suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _products = []; _error = null; _lastSearchTerm = ''; }); },) : null,), onSubmitted: _searchProducts,),
            const SizedBox(height: 16),
            Expanded(child: _buildResultsArea(),),
          ],),),);
  }

  Widget _buildResultsArea() {
    final txt = Theme.of(context).textTheme; final clr = Theme.of(context).colorScheme; final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    else if (_error != null) { return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_error!, style: TextStyle(color: clr.error, fontSize: 16), textAlign: TextAlign.center,),)); }
    else if (_products.isNotEmpty) {
      return ListView.builder(itemCount: _products.length, itemBuilder: (context, index) {
          final p = _products[index];
          return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => _navigateToDetails(context, p), child: Padding(padding: const EdgeInsets.all(12.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Afbeelding
                ClipRRect(borderRadius: BorderRadius.circular(4.0), child: SizedBox(width: 70, height: 70, child: p.imageUrl != null ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, pr) => pr == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2.0, value: pr.expectedTotalBytes != null ? pr.cumulativeBytesLoaded / pr.expectedTotalBytes! : null)),
                          errorBuilder: (ctx, err, st) => Container(color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.broken_image, color: Colors.grey[400])),)
                        : Container(color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.image_not_supported, color: Colors.grey[400])),),),
                const SizedBox(width: 12),
                // Tekstuele Info
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title, style: txt.titleMedium?.copyWith(height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis,), const SizedBox(height: 4),
                      Text('Art: ${p.articleCode}', style: txt.bodyMedium,),
                      if (p.eanCode != null) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text('EAN: ${p.eanCode}', style: txt.bodySmall)),
                      const SizedBox(height: 6),
                      // Prijs & Korting Weergave
                      Row( crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (p.priceString != null)
                            Flexible( child: RichText( text: TextSpan( style: txt.bodyMedium?.copyWith(color: txt.bodyLarge?.color), children: [
                                  if (p.oldPriceString != null) TextSpan( text: '€ ${p.oldPriceString}  ', style: TextStyle( decoration: TextDecoration.lineThrough, color: Colors.grey[600], fontSize: txt.bodySmall?.fontSize ?? 12,), ),
                                  TextSpan( text: '€ ${p.priceString}', style: TextStyle( fontSize: txt.titleMedium?.fontSize ?? 16, color: clr.primary, fontWeight: FontWeight.bold,),),
                                ],),),)
                          else Text('Prijs?', style: txt.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                          const SizedBox(width: 8),
                          if (p.discountLabel != null)
                            Flexible( child: Chip( label: Text(p.discountLabel!, overflow: TextOverflow.ellipsis), labelStyle: txt.labelSmall?.copyWith(color: isDarkMode ? Colors.black : clr.onErrorContainer, fontWeight: isDarkMode ? FontWeight.bold : FontWeight.normal,), backgroundColor: isDarkMode ? Colors.orange[700] : clr.errorContainer, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(4.0), side: BorderSide.none, ),),),
                        ],
                      ),
                    ],),),
              ],),),),);
        },);
    } else { return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_lastSearchTerm.isEmpty ? 'Zoek of scan.' : 'Geen producten voor "$_lastSearchTerm".', textAlign: TextAlign.center, style: txt.bodyMedium,),)); }
  }
}