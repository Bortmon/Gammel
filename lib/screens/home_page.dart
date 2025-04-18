// lib/screens/home_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;

import '../models/login_result.dart'; // Importeer models
import '../models/product.dart';
import 'product_details_screen.dart'; // Importeer andere screens
import 'schedule_screen.dart';
import 'scanner_screen.dart';

class HomePage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final VoidCallback onThemeModeChanged;
  final bool isLoggedIn;
  final String? authToken;
  final String? employeeId;
  final String? nodeId;
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
    _searchController.addListener(() {
      setState(() {}); // Update UI when search text changes (for clear button)
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToScanner({bool fromDetails = false}) async {
    try {
      final String? barcodeValue = await Navigator.push<String>( context, MaterialPageRoute(builder: (context) => const ScannerScreen()), );
      if (!mounted) return;
      if (barcodeValue != null && barcodeValue.isNotEmpty) {
        // Als we van details kwamen, pop eerst die pagina
        if (fromDetails && Navigator.canPop(context)) {
          Navigator.pop(context);
          await Future.delayed(const Duration(milliseconds: 50)); // Kleine delay
        }
        _searchController.text = barcodeValue;
        _searchProducts(barcodeValue);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = "Fout scanner: $e"; _isLoading = false; });
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() { _isLoading = true; _error = null; _products = []; _lastSearchTerm = query; });
    final url = Uri.parse('https://www.gamma.nl/assortiment/zoeken?text=${Uri.encodeComponent(query)}');
    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final document = parse(response.body);
        final List<Product> foundProducts = _parseProducts(document);
        setState(() {
          _products = foundProducts;
          if (_products.isEmpty && _lastSearchTerm.isNotEmpty) {
            _error = 'Geen producten gevonden voor "$_lastSearchTerm".';
          }
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Fout: Status ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      print('Error search results: $e');
      if (!mounted) return;
      setState(() { _error = 'Fout: $e'; _isLoading = false; });
    }
  }

 List<Product> _parseProducts(dom.Document document) {
    final products = <Product>[];
    final productElements = document.querySelectorAll('article.js-product-tile');
    for (final element in productElements) {
      String? imageUrl;
      String? priceString;
      try {
        String title = element.querySelector('div.product-tile-name a')?.text.trim() ?? element.querySelector('a.click-mask')?.attributes['title']?.trim() ?? 'Titel?';
        String? productUrl = element.querySelector('a.click-mask')?.attributes['href'];
        if (productUrl != null && !productUrl.startsWith('http')) {
          if (!productUrl.startsWith('/')) { productUrl = '/$productUrl'; }
          productUrl = 'https://www.gamma.nl$productUrl';
        }
        String? articleCode = element.attributes['data-objectid']?.trim();
        if (articleCode != null && articleCode.isNotEmpty && articleCode.length > 1) {
          if (int.tryParse(articleCode.substring(0, 1)) == null) { articleCode = articleCode.substring(1); }
        }
        String? eanCode = element.attributes['data-ean']?.trim();
        if (articleCode == null || articleCode.isEmpty) { articleCode = eanCode ?? 'Code?'; eanCode = null; }
        else if (eanCode == null || eanCode.isEmpty) { eanCode = null; }

        final imageContainer = element.querySelector('div.product-tile-image');
        if (imageContainer != null) {
          final imageElement = imageContainer.querySelector('img:not(.sticker)');
          if (imageElement != null) { imageUrl = imageElement.attributes['data-src'] ?? imageElement.attributes['src']; }
          else { final fallbackImageElement = imageContainer.querySelector('img'); imageUrl = fallbackImageElement?.attributes['data-src'] ?? fallbackImageElement?.attributes['src']; }
          if (imageUrl != null && !imageUrl.startsWith('http')) imageUrl = null;
        }

        final priceIntElement = element.querySelector('div.product-tile-price-current');
        final priceDecElement = element.querySelector('span.product-tile-price-decimal');
        if (priceIntElement != null && priceDecElement != null) {
          String intPart = priceIntElement.text.trim().replaceAll('.', '');
          String decPart = priceDecElement.text.trim();
          if (intPart.isNotEmpty && decPart.isNotEmpty) { priceString = '$intPart.$decPart'; }
        }
        if (priceString == null) { String? dataPrice = element.attributes['data-price']?.trim(); if (dataPrice != null) priceString = dataPrice; }

        if (title != 'Titel?' && articleCode != 'Code?') {
          products.add(Product( title: title, articleCode: articleCode, eanCode: eanCode, imageUrl: imageUrl, productUrl: productUrl, priceString: priceString ));
        }
      } catch (e) { print("[Parser Results] Error: $e"); }
    }
    return products;
  }


  Future<void> _navigateToDetails(BuildContext context, Product product) async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product),),);
    if (mounted && result != null && result.isNotEmpty) {
      print("[Nav] Barcode '$result' from details.");
      _searchController.text = result;
      _searchProducts(result);
    }
  }

  void _navigateToScheduleScreen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleScreen(
          authToken: widget.authToken,
          isLoggedIn: widget.isLoggedIn,
          employeeId: widget.employeeId,
          nodeId: widget.nodeId,
          loginCallback: widget.loginCallback,
          logoutCallback: widget.logoutCallback,
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0), // Meer verticale padding
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Zoek product of scan barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                          _searchController.clear();
                          setState(() { _products = []; _error = null; _lastSearchTerm = ''; });
                        },) : null,
              ),
              onSubmitted: _searchProducts,
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResultsArea(),),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    final txt = Theme.of(context).textTheme;
    final clr = Theme.of(context).colorScheme;
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    else if (_error != null) { return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_error!, style: TextStyle(color: clr.error, fontSize: 16), textAlign: TextAlign.center,),)); }
    else if (_products.isNotEmpty) {
      return ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _navigateToDetails(context, p),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: SizedBox(
                        width: 70, height: 70,
                        child: p.imageUrl != null
                            ? Image.network( p.imageUrl!, fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, pr) => pr == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2.0, value: pr.expectedTotalBytes != null ? pr.cumulativeBytesLoaded / pr.expectedTotalBytes! : null)),
                                errorBuilder: (ctx, err, st) => Container(color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.broken_image, color: Colors.grey[400])),
                              )
                            : Container(color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.image_not_supported, color: Colors.grey[400])),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: txt.titleMedium?.copyWith(height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis,),
                          const SizedBox(height: 4),
                          Text('Art: ${p.articleCode}', style: txt.bodyMedium,),
                          if (p.eanCode != null) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text('EAN: ${p.eanCode}', style: txt.bodySmall)),
                          if (p.priceString != null) Padding(padding: const EdgeInsets.only(top: 6.0), child: Text('€ ${p.priceString}', style: txt.titleMedium?.copyWith(color: clr.primary, fontWeight: FontWeight.bold),),),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else { return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_lastSearchTerm.isEmpty ? 'Zoek of scan.' : 'Geen producten voor "$_lastSearchTerm".', textAlign: TextAlign.center, style: txt.bodyMedium,),)); }
  }
}