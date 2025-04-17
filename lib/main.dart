import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'dart:convert'; // Needed for jsonDecode

// --- Data Model ---

/// Represents a product scraped from the website or obtained via API.
class Product {
  final String title;
  final String articleCode; // Article number (cleaned data-objectid)
  final String? eanCode;     // EAN / Barcode (data-ean)
  final String? imageUrl;    // Thumbnail URL (from search results)
  final String? productUrl;  // URL to the detail page
  final String? priceString; // Price string (e.g., "19.99")

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

// --- Main Application Entry Point ---

void main() {
  runApp(const MyApp());
}

// --- Root Application Widget (Manages Theme) ---

/// The root widget of the application, responsible for managing the theme mode.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void toggleThemeMode() {
     final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
     _changeThemeMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
     final baseLightTheme = ThemeData.light(useMaterial3: true);
     final baseDarkTheme = ThemeData.dark(useMaterial3: true);

     final lightColorScheme = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
     );

     final darkColorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF75a7ff),
        brightness: Brightness.dark,
        background: const Color(0xFF1F1F1F),
        surface: const Color(0xFF2A2A2A),
        primary: const Color(0xFF75a7ff),
        onPrimary: Colors.black,
        secondary: const Color(0xFFb8c7ff),
        onSecondary: Colors.black,
        surfaceVariant: const Color(0xFF3A3A3A),
        error: Colors.redAccent[100]
     );

    final lightTheme = baseLightTheme.copyWith(
        colorScheme: lightColorScheme,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          elevation: 2,
          iconTheme: IconThemeData(color: lightColorScheme.onPrimary),
          actionsIconTheme: IconThemeData(color: lightColorScheme.onPrimary),
        ),
        cardTheme: CardTheme(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0), ),
          color: lightColorScheme.surface,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
           filled: true, fillColor: Colors.grey[100],
           contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
           border: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none, ),
           enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none, ),
           focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: lightColorScheme.primary, width: 1.5), ),
           labelStyle: TextStyle(color: Colors.grey[600]),
           prefixIconColor: Colors.grey[600], suffixIconColor: Colors.grey[600],
        ),
        textTheme: baseLightTheme.textTheme.copyWith(
          bodySmall: baseLightTheme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])
        ).apply(displayColor: Colors.black87, bodyColor: Colors.black87),
     );

     final darkTheme = baseDarkTheme.copyWith(
        colorScheme: darkColorScheme,
         appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF2B3035),
          foregroundColor: darkColorScheme.onSurface,
          elevation: 1,
          iconTheme: IconThemeData(color: darkColorScheme.onSurface),
          actionsIconTheme: IconThemeData(color: darkColorScheme.onSurface),
        ),
        scaffoldBackgroundColor: darkColorScheme.background,
        cardTheme: CardTheme(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0), ),
          color: darkColorScheme.surface,
          surfaceTintColor: Colors.transparent,
        ),
         inputDecorationTheme: InputDecorationTheme(
           filled: true, fillColor: Colors.grey[850],
           contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
           border: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none, ),
           enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none, ),
           focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: darkColorScheme.primary, width: 1.5), ),
           labelStyle: TextStyle(color: Colors.grey[400]),
           prefixIconColor: Colors.grey[400], suffixIconColor: Colors.grey[400],
        ),
        textTheme: baseDarkTheme.textTheme.apply(
          bodyColor: Colors.grey[300],
          displayColor: Colors.white,
        ).copyWith(
          bodySmall: baseDarkTheme.textTheme.bodySmall?.copyWith(color: Colors.grey[500])
        ),
         iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: darkColorScheme.onSurface)),
         iconTheme: IconThemeData(color: darkColorScheme.onSurface.withOpacity(0.8)),
         dividerTheme: DividerThemeData(color: Colors.grey[700], thickness: 0.5),
     );

    return MaterialApp(
      title: 'Gammel',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: HomePage(
          currentThemeMode: _themeMode,
          onThemeModeChanged: toggleThemeMode,
        ),
      debugShowCheckedModeBanner: false,
    );
  }
} // <<< Einde MyAppState


// --- HomePage Widget (Main Screen) ---
/// Displays the search bar and the list of found products.
/// Allows navigation to the scanner and product details.
/// Provides a theme toggle button.
class HomePage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final VoidCallback onThemeModeChanged;

  const HomePage({
      super.key,
      required this.currentThemeMode,
      required this.onThemeModeChanged,
  });

  @override State<HomePage> createState() => _HomePageState();
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
    // Listener to update the clear button visibility in the search field
    _searchController.addListener(() { setState(() {}); });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Navigates to the scanner screen.
  /// If returning from details screen with a barcode, handles navigation.
  /// On scan result, updates search bar and starts search.
  Future<void> _navigateToScanner({bool fromDetails = false}) async {
    try {
      final String? barcodeValue = await Navigator.push<String>( context, MaterialPageRoute(builder: (context) => const ScannerScreen()), );
      if (!mounted) return; // Check if the widget is still in the tree

      if (barcodeValue != null && barcodeValue.isNotEmpty) {
        // If called from details screen, pop that screen first
        if (fromDetails && Navigator.canPop(context)) {
          Navigator.pop(context);
          await Future.delayed(const Duration(milliseconds: 50)); // Small delay
        }
        _searchController.text = barcodeValue;
        _searchProducts(barcodeValue);
      } else {
        print("[Scanner] Scanner closed without result.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = "Fout bij openen scanner: $e"; _isLoading = false; });
    }
  }

  /// Fetches search results from Gamma website using the provided query.
  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() { _isLoading = true; _error = null; _products = []; _lastSearchTerm = query; });

    final url = Uri.parse('https://www.gamma.nl/assortiment/zoeken?text=${Uri.encodeComponent(query)}');
    print('[HTTP] Fetching search URL: $url');

    try {
      final response = await http.get( url, headers: { 'User-Agent': _userAgent });
      if (!mounted) return;

      if (response.statusCode == 200) {
        print('[HTTP] Search response status 200 OK');
        final document = parse(response.body);
        final List<Product> foundProducts = _parseProducts(document); // Parse the HTML response
        setState(() {
          _products = foundProducts;
          if (_products.isEmpty && _lastSearchTerm.isNotEmpty) {
             _error = 'Geen producten gevonden voor "$_lastSearchTerm".';
          }
          _isLoading = false;
        });
      } else {
        print('[HTTP] Search response status: ${response.statusCode}');
        setState(() { _error = 'Fout bij ophalen zoekresultaten: Status ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      print('[HTTP] Error fetching/parsing search results: $e');
      if (!mounted) return;
      setState(() { _error = 'Netwerkfout of parseerfout: $e'; _isLoading = false; });
    }
  }

  /// Parses the HTML of the search results page to extract product data.
  /// Note: This is highly dependent on the website's HTML structure and may break.
  List<Product> _parseProducts(dom.Document document) {
    final products = <Product>[];
    // Selector for the main container of each product tile
    final productElements = document.querySelectorAll('article.js-product-tile');
    int productIndex = 0;

    for (final element in productElements) {
      productIndex++;
      String? imageUrl;
      String? priceString;

      try {
        String title = element.querySelector('div.product-tile-name a')?.text.trim() ??
                       element.querySelector('a.click-mask')?.attributes['title']?.trim() ??
                       'Titel niet gevonden';

        String? productUrl = element.querySelector('a.click-mask')?.attributes['href'];
        if (productUrl != null && !productUrl.startsWith('http')) {
            if (!productUrl.startsWith('/')) { productUrl = '/$productUrl'; }
            productUrl = 'https://www.gamma.nl$productUrl';
        }

        String? articleCode = element.attributes['data-objectid']?.trim();
        if (articleCode != null && articleCode.isNotEmpty && articleCode.length > 1) {
            final firstChar = articleCode.substring(0, 1);
            if (int.tryParse(firstChar) == null) {
                articleCode = articleCode.substring(1);
            }
        }

        String? eanCode = element.attributes['data-ean']?.trim();

        if (articleCode == null || articleCode.isEmpty) {
            articleCode = eanCode ?? 'Code niet gevonden';
            eanCode = null; // Clear EAN if used as fallback
        } else if (eanCode == null || eanCode.isEmpty) {
             eanCode = null;
        }

        final imageContainer = element.querySelector('div.product-tile-image');
        if (imageContainer != null) {
            final imageElement = imageContainer.querySelector('img:not(.sticker)');
            if (imageElement != null) {
                imageUrl = imageElement.attributes['data-src'] ?? imageElement.attributes['src'];
            } else {
                final fallbackImageElement = imageContainer.querySelector('img');
                imageUrl = fallbackImageElement?.attributes['data-src'] ?? fallbackImageElement?.attributes['src'];
            }
            if (imageUrl != null && !imageUrl.startsWith('http')) {
                imageUrl = null; // Ignore relative URLs
            }
        }

        final priceIntElement = element.querySelector('div.product-tile-price-current');
        final priceDecElement = element.querySelector('span.product-tile-price-decimal');
        if (priceIntElement != null && priceDecElement != null) {
            String intPart = priceIntElement.text.trim().replaceAll('.', '');
            String decPart = priceDecElement.text.trim();
            if (intPart.isNotEmpty && decPart.isNotEmpty) {
                priceString = '$intPart.$decPart';
            }
        }
        if (priceString == null) {
            String? dataPrice = element.attributes['data-price']?.trim();
            if (dataPrice != null) { priceString = dataPrice; }
        }

        if (title != 'Titel niet gevonden' && articleCode != 'Code niet gevonden') {
           products.add(Product(
             title: title,
             articleCode: articleCode,
             eanCode: eanCode,
             imageUrl: imageUrl,
             productUrl: productUrl,
             priceString: priceString
           ));
        }
      } catch (e) {
        print("[Parser Results] ($productIndex) Error parsing search item: $e");
      }
    }
    return products;
  }

  /// Navigates to the detail screen, passing the product data.
  /// Waits for a potential result (scanned barcode) from the detail screen.
  Future<void> _navigateToDetails(BuildContext context, Product product) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute( builder: (context) => ProductDetailsScreen(product: product), ),
    );

    if (mounted && result != null && result.isNotEmpty) {
        print("[Navigation] Barcode '$result' received from detail page.");
        _searchController.text = result;
        _searchProducts(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness platformBrightness = MediaQuery.platformBrightnessOf(context);
    final bool isCurrentlyDark = (widget.currentThemeMode == ThemeMode.dark || (widget.currentThemeMode == ThemeMode.system && platformBrightness == Brightness.dark));
    final IconData themeIcon = isCurrentlyDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gammel'),
        actions: [
          IconButton(
            icon: Icon(themeIcon),
            tooltip: isCurrentlyDark ? 'Lichte modus' : 'Donkere modus',
            onPressed: widget.onThemeModeChanged,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: () => _navigateToScanner(),
            tooltip: 'Scan Barcode',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
        child: Column(
          children: [
             TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Zoek product of scan barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            // Optionally reset search results when clearing manually
                            // setState((){ _products = []; _error = null; _lastSearchTerm = ''; });
                          },
                         )
                      : null,
              ),
              onSubmitted: (value) => _searchProducts(value),
            ),
            const SizedBox(height: 16),
            Expanded( child: _buildResultsArea(), ),
          ],
        ),
      ),
    );
  }

  /// Builds the list view for search results, or shows loading/error/empty messages.
  Widget _buildResultsArea() {
     final textTheme = Theme.of(context).textTheme;
     final colorScheme = Theme.of(context).colorScheme;

     if (_isLoading) {
       return const Center(child: CircularProgressIndicator());
     } else if (_error != null) {
       return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Text( _error!, style: TextStyle(color: colorScheme.error, fontSize: 16), textAlign: TextAlign.center, ), ));
     } else if (_products.isNotEmpty) {
       return ListView.builder(
         itemCount: _products.length,
         itemBuilder: (context, index) {
           final product = _products[index];
           return Card(
             clipBehavior: Clip.antiAlias,
             child: InkWell(
               onTap: () { _navigateToDetails(context, product); },
               child: Padding(
                 padding: const EdgeInsets.all(12.0),
                 child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
                     // Image Thumbnail
                     ClipRRect(
                       borderRadius: BorderRadius.circular(4.0),
                       child: SizedBox(
                         width: 70, height: 70,
                         child: product.imageUrl != null
                             ? Image.network( product.imageUrl!, fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2.0, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                                errorBuilder: (ctx, err, st) => Container( color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, color: Colors.grey[400])),
                               )
                             : Container( color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), alignment: Alignment.center, child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400])),
                       ),
                     ),
                     const SizedBox(width: 12),
                     // Product Text Info
                     Expanded(
                       child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                         Text( product.title, style: textTheme.titleMedium?.copyWith(height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis, ),
                         const SizedBox(height: 4),
                         Text( 'Art.nr: ${product.articleCode}', style: textTheme.bodyMedium, ),
                         if (product.eanCode != null && product.eanCode!.length >= 3)
                            Padding( padding: const EdgeInsets.only(top: 2.0), child: RichText( text: TextSpan( style: textTheme.bodySmall, children: <TextSpan>[ TextSpan(text: 'EAN: ${product.eanCode!.substring(0, product.eanCode!.length - 3)}'), TextSpan( text: product.eanCode!.substring(product.eanCode!.length - 3), style: const TextStyle(fontWeight: FontWeight.bold), ), ], ), ), )
                         else if (product.eanCode != null)
                            Padding( padding: const EdgeInsets.only(top: 2.0), child: Text('EAN: ${product.eanCode}', style: textTheme.bodySmall)),
                         if (product.priceString != null)
                           Padding( padding: const EdgeInsets.only(top: 6.0), child: Text( '€ ${product.priceString}', style: textTheme.titleMedium?.copyWith( color: colorScheme.primary, fontWeight: FontWeight.bold ), ), ),
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
     } else {
       // Initial state or no results found message
       return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Text( _lastSearchTerm.isEmpty ? 'Voer een zoekterm in of scan een barcode.' : 'Geen resultaten gevonden voor "$_lastSearchTerm".', textAlign: TextAlign.center, style: textTheme.bodyMedium, ), ));
     }
  }
} // <<< EINDE _HomePageState


// --- ProductDetailsScreen Widget ---
/// Displays detailed information about a selected product, including description,
/// specifications, and attempts to fetch store stock via API.
class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});
  @override State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  // State variables
  bool _isLoadingDetails = true;
  String? _description;
  String? _specifications;
  String? _detailImageUrl;
  String? _detailPriceString;
  String? _detailsError;
  bool _isLoadingStock = true;
  Map<String, int?> _storeStocks = {}; // Map: StoreName -> Stock count (null if unknown)
  String? _stockError;

  // Constants for scraping and API calls
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  final Map<String, String> _targetStores = {
    'Gamma Haarlem': '39', 'Gamma Velserbroek': '858', 'Gamma Cruquius': '669',
    'Gamma Hoofddorp': '735', 'Gamma Heemskerk': '857', 'Karwei Haarlem': '647',
    'Karwei Haarlem-Zuid': '844',
  };
  final String gammaStockApiBase = 'https://api.gamma.nl/stock/2/';
  final String karweiStockApiBase = 'https://api.karwei.nl/stock/2/'; // Assumed same base path
  final String gammaCookieName = 'PREFERRED-STORE-UID';
  final String gammaCookieValueHaarlem = '39'; // Haarlem ID for potential preference

  @override
  void initState() {
    super.initState();
    _detailImageUrl = widget.product.imageUrl; // Use thumbnail as initial image
    _detailPriceString = widget.product.priceString; // Use list price as initial price
    _fetchProductDetails(); // Start fetching HTML details
    _fetchSpecificStoreStocks(); // Start fetching API stock
  }

  /// Fetches and parses details (description, specs, image, price) from the product detail page HTML.
  /// This relies on the website's HTML structure.
  Future<void> _fetchProductDetails() async {
    setState(() { _isLoadingDetails = true; _description = null; _specifications = null; _detailsError = null; });
    if (widget.product.productUrl == null) {
      setState(() { _detailsError = "Product URL ontbreekt."; _isLoadingDetails = false; });
      return;
    }

    final url = Uri.parse(widget.product.productUrl!);
    print('[Parser Details] Fetching details from URL: $url');
    final Map<String, String> requestHeaders = { 'User-Agent': _userAgent };

    try {
      final response = await http.get( url, headers: requestHeaders );
      if (!mounted) return; // Check if widget is still mounted

      if (response.statusCode == 200) {
        final document = parse(response.body);

        // Parse Description
        final infoContentElement = document.querySelector('#product-info-content');
        if (infoContentElement != null) {
          String shortInfoText = infoContentElement.querySelectorAll('div.product-info-short ul li').map((li) => '• ${li.text.trim()}').join('\n');
          final descriptionElement = infoContentElement.querySelector('div.description div[itemprop="description"] p') ?? infoContentElement.querySelector('div.description p');
          String mainDescriptionText = descriptionElement?.text.trim() ?? '';
          List<String> descriptionParts = [];
          if (shortInfoText.isNotEmpty) descriptionParts.add(shortInfoText);
          if (mainDescriptionText.isNotEmpty) descriptionParts.add(mainDescriptionText);
          _description = descriptionParts.join('\n\n').trim();
          if (_description!.isEmpty) _description = null;
        }

        // Parse Specifications
        final specsContentElement = document.querySelector('#product-specs');
        if (specsContentElement != null) {
          final List<String> specLines = [];
          final specTables = specsContentElement.querySelectorAll('table.fancy-table');
          if (specTables.isNotEmpty) {
            for (var table in specTables) {
              final groupHeaderElement = table.querySelector('thead tr.group-name th strong');
              if (groupHeaderElement != null) { if (specLines.isNotEmpty) specLines.add(''); specLines.add('${groupHeaderElement.text.trim()}:'); }
              final specRows = table.querySelectorAll('tbody tr');
              for (var row in specRows) {
                final keyElement = row.querySelector('th.attrib');
                final valueElement = row.querySelector('td.value .feature-value');
                if (keyElement != null && valueElement != null) {
                  final key = keyElement.text.trim(); final value = valueElement.text.trim();
                  if (key.isNotEmpty) { specLines.add('  $key: $value'); }
                }
              }
            }
            _specifications = specLines.join('\n').trim();
            if (_specifications!.isEmpty) _specifications = 'Specificaties sectie leeg.';
          } else { _specifications = 'Geen specificatietabellen gevonden.'; }
        } else { _specifications = 'Specificaties sectie niet gevonden.'; }

        // Parse Detail Image URL
        final imageElement = document.querySelector('img.product-main-image');
        String? fetchedDetailImageUrl;
        if (imageElement != null) {
             String? dataSrcAttr = imageElement.attributes['data-src'];
             String? srcAttr = imageElement.attributes['src'];
             fetchedDetailImageUrl = dataSrcAttr ?? srcAttr;
             if (fetchedDetailImageUrl != null && fetchedDetailImageUrl.contains('/placeholders/')) {
                 String? alternativeUrl = (fetchedDetailImageUrl == dataSrcAttr) ? srcAttr : dataSrcAttr;
                 if (alternativeUrl != null && !alternativeUrl.contains('/placeholders/')) { fetchedDetailImageUrl = alternativeUrl; }
                 else { fetchedDetailImageUrl = null; }
             }
             if (fetchedDetailImageUrl != null && !fetchedDetailImageUrl.startsWith('http')) fetchedDetailImageUrl = null;
        } else {
            final metaImageElement = document.querySelector('meta[itemprop="image"]');
            fetchedDetailImageUrl = metaImageElement?.attributes['content'];
            if (fetchedDetailImageUrl != null && !fetchedDetailImageUrl.startsWith('http')) fetchedDetailImageUrl = null;
        }
        if (fetchedDetailImageUrl != null && fetchedDetailImageUrl != _detailImageUrl) {
            _detailImageUrl = fetchedDetailImageUrl;
        }

        // Parse Detail Price
        String? potentialPrice;
        final priceMetaElement = document.querySelector('meta[itemprop="price"]');
        potentialPrice = priceMetaElement?.attributes['content']?.trim();
        if (potentialPrice == null || potentialPrice.isEmpty) {
            final priceElement = document.querySelector('.price-sales-standard');
            potentialPrice = priceElement?.text.trim().replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.');
        }
        if (potentialPrice == null || potentialPrice.isEmpty) {
           final integerPartElement = document.querySelector('.pdp-price__integer');
           final decimalPartElement = document.querySelector('.pdp-price__fractional');
           final integerPart = integerPartElement?.text.trim();
           final decimalPart = decimalPartElement?.text.trim();
           if (integerPart != null && integerPart.isNotEmpty && decimalPart != null && decimalPart.isNotEmpty) {
              potentialPrice = '$integerPart.$decimalPart';
           }
        }
        if (potentialPrice != null && potentialPrice.isNotEmpty && _detailPriceString != potentialPrice) {
           _detailPriceString = potentialPrice; // Update price if found and different
        }

        // Check for overall errors
        if (_description == null && (_specifications == null || _specifications!.contains('niet gevonden') || _specifications!.contains('leeg'))) {
            _detailsError = 'Kon geen omschrijving of specificaties vinden.';
        }

      } else {
        _detailsError = 'Fout bij ophalen details: Status ${response.statusCode}';
      }
    } catch (e) {
      print('[Parser Details] Error fetching/parsing details: $e');
      _detailsError = 'Fout bij ophalen/verwerken details: $e';
    }

    if (mounted) {
      setState(() { _isLoadingDetails = false; });
    }
  }

  /// Fetches stock levels for specific stores via the API.
  /// This is experimental and depends on internal API stability.
  Future<void> _fetchSpecificStoreStocks() async {
    setState(() { _isLoadingStock = true; _stockError = null; _storeStocks = {}; });
    String productIdentifier = widget.product.articleCode;

    if (productIdentifier == 'Code niet gevonden') {
       setState(() { _stockError = "Artikelcode onbekend."; _isLoadingStock = false; });
       return;
    } else {
        // Clean the article code (remove leading non-digits and zeros)
        try {
            productIdentifier = int.parse(productIdentifier).toString();
        } catch (e) {
            print("[Stock API] Warning: Could not parse articleCode '$productIdentifier' to int. Using original value.");
        }
    }
    print("[Stock API] Using cleaned identifier (articleCode): $productIdentifier for API calls.");


    final Map<String, int?> combinedStocks = {};
    String currentStockError = '';
    final gammaStoreEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma'));
    final karweiStoreEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei'));

    final String gammaUidsParam = gammaStoreEntries.map((entry) => 'Stock-${entry.value}-${productIdentifier}').join(',');
    final String karweiUidsParam = karweiStoreEntries.map((entry) => 'Stock-${entry.value}-${productIdentifier}').join(',');

    List<Future<void>> apiCalls = [];

    // --- Gamma API Call ---
    if (gammaUidsParam.isNotEmpty) {
      final gammaUrl = Uri.parse('$gammaStockApiBase?uids=$gammaUidsParam');
      print('[Stock API - Gamma] Fetching stock from URL: $gammaUrl');
      final Map<String, String> gammaHeaders = { 'User-Agent': _userAgent, 'Origin': 'https://www.gamma.nl', 'Referer': 'https://www.gamma.nl/', 'Cookie': '$gammaCookieName=$gammaCookieValueHaarlem' };
      apiCalls.add(
        http.get(gammaUrl, headers: gammaHeaders).then((response) {
           print("[Stock API - Gamma] Response Status Code: ${response.statusCode}");
           // print("[Stock API - Gamma] Response Body: ${response.body}"); // Keep commented unless debugging
           if (response.statusCode == 200) {
              try {
                 final List<dynamic> stockData = jsonDecode(response.body);
                 for (var storeEntry in gammaStoreEntries) {
                     final storeName = storeEntry.key;
                     final storeId = storeEntry.value;
                     final expectedUid = 'Stock-$storeId-$productIdentifier';
                     var storeStockInfo = stockData.firstWhere( (item) => item is Map && item['uid'] == expectedUid, orElse: () => null, );
                     if (storeStockInfo != null) {
                        final dynamic quantityValue = storeStockInfo['quantity']; // Assumed key
                        if (quantityValue is int) { combinedStocks[storeName] = quantityValue; }
                        else if (quantityValue is String) { combinedStocks[storeName] = int.tryParse(quantityValue); }
                        else { combinedStocks[storeName] = null; }
                     } else {
                        combinedStocks[storeName] = null; // Product not found for this store in response
                     }
                 }
              } catch (e) { print("[Stock API - Gamma] Error parsing JSON: $e"); currentStockError += 'Fout Gamma voorraad. '; }
           } else { print("[Stock API - Gamma] API call failed: ${response.statusCode}"); currentStockError += 'Kon Gamma voorraad niet ophalen (${response.statusCode}). '; }
        }).catchError((e) { print("[Stock API - Gamma] Network error: $e"); currentStockError += 'Netwerkfout Gamma voorraad. '; })
      );
    }

    // --- Karwei API Call ---
    if (karweiUidsParam.isNotEmpty) {
      final karweiUrl = Uri.parse('$karweiStockApiBase?uids=$karweiUidsParam');
      print('[Stock API - Karwei] Fetching stock from URL: $karweiUrl');
      final Map<String, String> karweiHeaders = { 'User-Agent': _userAgent, 'Origin': 'https://www.karwei.nl', 'Referer': 'https://www.karwei.nl/', }; // No cookie needed for Karwei?
       apiCalls.add(
         http.get(karweiUrl, headers: karweiHeaders).then((response) {
           print("[Stock API - Karwei] Response Status Code: ${response.statusCode}");
           // print("[Stock API - Karwei] Response Body: ${response.body}"); // Keep commented unless debugging
           if (response.statusCode == 200) {
              try {
                 final List<dynamic> stockData = jsonDecode(response.body);
                 for (var storeEntry in karweiStoreEntries) {
                     final storeName = storeEntry.key;
                     final storeId = storeEntry.value;
                     final expectedUid = 'Stock-$storeId-$productIdentifier';
                     var storeStockInfo = stockData.firstWhere( (item) => item is Map && item['uid'] == expectedUid, orElse: () => null, );
                     if (storeStockInfo != null) {
                        final dynamic quantityValue = storeStockInfo['quantity']; // Assumed key
                        if (quantityValue is int) { combinedStocks[storeName] = quantityValue; }
                        else if (quantityValue is String) { combinedStocks[storeName] = int.tryParse(quantityValue); }
                        else { combinedStocks[storeName] = null; }
                     } else {
                        combinedStocks[storeName] = null; // Product not found for this store in response
                     }
                 }
              } catch (e) { print("[Stock API - Karwei] Error parsing JSON: $e"); currentStockError += 'Fout Karwei voorraad. '; }
           } else { print("[Stock API - Karwei] API call failed: ${response.statusCode}"); currentStockError += 'Kon Karwei voorraad niet ophalen (${response.statusCode}). '; }
        }).catchError((e) { print("[Stock API - Karwei] Network error: $e"); currentStockError += 'Netwerkfout Karwei voorraad. '; })
      );
    }

    // Wait for both API calls to complete
    await Future.wait(apiCalls);

    // Update the state after all calls are done
    if (mounted) {
      setState(() {
        _storeStocks = combinedStocks;
        _stockError = currentStockError.isEmpty ? null : currentStockError.trim();
        _isLoadingStock = false;
      });
    }
  }


  /// Navigates to the scanner screen and returns the result to HomePage.
  Future<void> _navigateToScannerFromDetails() async {
    try {
      final String? barcodeValue = await Navigator.push<String>( context, MaterialPageRoute(builder: (context) => const ScannerScreen()), );
      if (!mounted) return;
      if (barcodeValue != null && barcodeValue.isNotEmpty) {
        print("Scanner klaar op detailpagina, ga terug naar home met: $barcodeValue");
        Navigator.pop(context, barcodeValue); // Pop details screen and return barcode
      } else {
        print("Scanner gesloten zonder resultaat (vanaf details).");
      }
    } catch (e) {
      if (!mounted) return;
      print("Fout scanner vanaf details: $e");
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Fout bij starten scanner: $e')), );
    }
  }

  @override Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
        actions: [
           IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: _navigateToScannerFromDetails,
            tooltip: 'Scan nieuwe barcode',
           ),
        ],
       ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Product Image
            if (_detailImageUrl != null)
              Center( child: Padding( padding: const EdgeInsets.only(bottom: 20.0), child: ClipRRect( borderRadius: BorderRadius.circular(8.0), child: Image.network( _detailImageUrl!, height: 250, fit: BoxFit.contain, loadingBuilder: (ctx, child, progress) => progress == null ? child : Container( height: 250, alignment: Alignment.center, child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)), errorBuilder: (ctx, err, st) => Container( height: 250, color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, size: 80, color: Colors.grey[400])), ), ), ), )
            else if (_isLoadingDetails && _isLoadingStock) // Show loading only if both are loading and no image yet
              Container( height: 250, alignment: Alignment.center, child: const CircularProgressIndicator() )
            else // Show placeholder if no image available after loading
              Container( height: 250, color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), alignment: Alignment.center, child: Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey[400]) ),

            // Product Title and Codes
            Text(widget.product.title, style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row( children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: textTheme.bodySmall?.color),
                const SizedBox(width: 4),
                Text('Art.nr: ${widget.product.articleCode}', style: textTheme.bodyLarge),
                const SizedBox(width: 16),
                if (widget.product.eanCode != null) ...[
                   Icon(Icons.barcode_reader, size: 16, color: textTheme.bodySmall?.color),
                   const SizedBox(width: 4),
                   if (widget.product.eanCode!.length >= 3)
                     RichText( text: TextSpan( style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color), children: <TextSpan>[ TextSpan(text: widget.product.eanCode!.substring(0, widget.product.eanCode!.length - 3)), TextSpan( text: widget.product.eanCode!.substring(widget.product.eanCode!.length - 3), style: const TextStyle(fontWeight: FontWeight.bold), ), ], ), )
                   else
                     Text(widget.product.eanCode!, style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color)),
                ],
              ],
            ),
            if (widget.product.productUrl != null) ...[
              const SizedBox(height: 12),
              SelectableText(widget.product.productUrl!, style: textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
            ],

            // Price
            const SizedBox(height: 16),
            if (_isLoadingDetails && _detailPriceString == null)
               Text("Prijs laden...", style: textTheme.titleLarge?.copyWith(color: Colors.grey))
            else if (_detailPriceString != null)
               Text( '€ $_detailPriceString', style: textTheme.headlineSmall?.copyWith( color: colorScheme.primary, fontWeight: FontWeight.bold ), )
            else
               Text( 'Prijs niet beschikbaar', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey), ),
            const SizedBox(height: 16),

            // Store Stock Section (via API)
            const Divider(thickness: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text('Winkelvoorraad (indicatie)', style: textTheme.titleLarge?.copyWith(fontSize: 18)),
            ),
            _buildStoreStockSection(context, textTheme),
            const Divider(height: 32, thickness: 0.5),

            // Details Section (Description/Specifications)
            _buildDetailsSection(context, textTheme),
          ],
        ),
      ),
    );
  }

  /// Builds the section displaying stock information per store.
  Widget _buildStoreStockSection(BuildContext context, TextTheme textTheme) {
    if (_isLoadingStock) {
      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2.0)));
    }

    List<Widget> children = [];
    if (_stockError != null) {
      children.add( Center( child: Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Text( _stockError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), ));
    }

    if (_storeStocks.isEmpty && _stockError == null) {
      children.add(Center( child: Padding( padding: const EdgeInsets.all(8.0), child: Text( "Kon geen voorraad vinden voor de geselecteerde winkels.", style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.center, ), ), ));
    } else {
      // Sort stores: Gamma Haarlem first, then other Gamma, then Karwei, then alphabetically
       final sortedEntries = _storeStocks.entries.toList()
          ..sort((a, b) {
              bool aIsHaarlem = a.key == 'Gamma Haarlem'; bool bIsHaarlem = b.key == 'Gamma Haarlem'; if (aIsHaarlem) return -1; if (bIsHaarlem) return 1;
              bool aIsGamma = a.key.startsWith('Gamma'); bool bIsGamma = b.key.startsWith('Gamma'); if (aIsGamma && !bIsGamma) return -1; if (!aIsGamma && bIsGamma) return 1;
              return a.key.compareTo(b.key);
          });

      for (var entry in sortedEntries) {
        final storeName = entry.key;
        final stockCount = entry.value;
        final isHaarlem = storeName == 'Gamma Haarlem';
        IconData icon; Color color; String stockText;

        if (stockCount == null) { icon = Icons.help_outline; color = Colors.grey; stockText = "Niet in assortiment?"; }
        else if (stockCount > 5) { icon = Icons.check_circle_outline; color = Colors.green; stockText = "$stockCount stuks"; }
        else if (stockCount > 0) { icon = Icons.warning_amber_outlined; color = Colors.orange; stockText = "$stockCount stuks (laag)"; }
        else { icon = Icons.cancel_outlined; color = Colors.red; stockText = "Niet op voorraad"; }

        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0), // Slightly more vertical space
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    storeName,
                    style: textTheme.bodyMedium?.copyWith( fontWeight: isHaarlem ? FontWeight.bold : FontWeight.normal )
                )),
                Text(stockText, style: textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        );
      }
    }
     // Wrap in a container for potential background/padding
     return Container(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Column(children: children)
     );
  }

  /// Builds the section displaying description and specifications.
  Widget _buildDetailsSection(BuildContext context, TextTheme textTheme) {
     // Show loading indicator only if everything is still loading
     if (_isLoadingDetails && _isLoadingStock && _description == null && _specifications == null) {
        return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(), ));
     }
     // Show main error only if nothing else could be loaded
     else if (_detailsError != null && _description == null && _specifications == null && _storeStocks.isEmpty) {
        return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Text( _detailsError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), );
     }
     else {
       // Build section even if some parts are missing or errored
       return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
           // Show partial error message if details failed but stock might be okay
           if(_detailsError != null && (_description != null || _specifications != null))
              Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Text("Opmerking details: $_detailsError", style: TextStyle(color: Colors.orange[800], fontStyle: FontStyle.italic)), ),

           // Description
           if (_description != null && _description!.isNotEmpty) ...[
              Text('Omschrijving', style: textTheme.titleLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              SelectableText(_description!, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 24),
              const Divider(thickness: 0.5),
              const SizedBox(height: 24),
           ] else if (!_isLoadingDetails && _detailsError == null) ...[
              // Only show "not found" if loading is complete and there wasn't a general error
              Text('Omschrijving niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)),
              const SizedBox(height: 24),
           ],

           // Specifications
           if (_specifications != null && !_specifications!.contains('niet gevonden') && !_specifications!.contains('leeg') && _specifications!.isNotEmpty) ...[
              Text('Specificaties', style: textTheme.titleLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity, // Ensure container takes full width
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), // Use theme color
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SelectableText( _specifications!, style: textTheme.bodyMedium?.copyWith(height: 1.6, fontFamily: 'monospace'), )
              ),
           ] else if (!_isLoadingDetails && _detailsError == null) ...[
              // Only show "not found" if loading is complete and there wasn't a general error
              Text('Specificaties niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)),
           ],
         ],
       );
     }
  }
} // <<< EINDE _ProductDetailsScreenState


// --- ScannerScreen Widget ---
/// Displays the camera feed for scanning barcodes.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Called when a barcode is detected.
  void _handleDetection(BarcodeCapture capture) {
     if (_isProcessing) return; // Prevent multiple calls
     final Barcode? barcode = capture.barcodes.firstOrNull;
     if (barcode != null && barcode.rawValue != null) {
        final String code = barcode.rawValue!;
        print('[Scanner] Barcode gevonden: $code');
        setState(() { _isProcessing = true; });
        Navigator.pop(context, code); // Return the scanned code
     }
   }

  /// Toggles the flashlight.
  Future<void> _toggleTorchAndSetState() async {
     try {
       await controller.toggleTorch();
       // Update local state based on toggle action (actual state might not be readable directly)
       setState(() { _isTorchOn = !_isTorchOn; });
       print("[Scanner] Torch toggled.");
     } catch (e) {
       print("[Scanner] Fout bij togglen torch: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kan flitslicht niet bedienen: $e")));
     }
  }

  /// Switches between front and back camera.
  Future<void> _switchCameraAndSetState() async {
     try {
       await controller.switchCamera();
       // Update local state based on toggle action
       setState(() { _cameraFacing = (_cameraFacing == CameraFacing.back) ? CameraFacing.front : CameraFacing.back; });
       print("[Scanner] Camera switched to: $_cameraFacing");
     } catch (e) {
       print("[Scanner] Fout bij wisselen camera: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kan camera niet wisselen: $e")));
     }
  }

  @override
  Widget build(BuildContext context) {
    // Get current brightness for icon coloring
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = isDark ? Colors.white70 : Colors.white70; // AppBar foreground is set, use white70

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        elevation: 1,
        foregroundColor: Colors.white, // Ensure title is white
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back button is white
        actions: [
          IconButton(
            icon: Icon( _isTorchOn ? Icons.flash_on : Icons.flash_off_outlined, color: _isTorchOn ? Colors.yellowAccent[700] : iconColor, ),
            iconSize: 28.0,
            onPressed: _toggleTorchAndSetState,
            tooltip: 'Flitslicht',
          ),
          IconButton(
            icon: Icon( _cameraFacing == CameraFacing.back ? Icons.flip_camera_ios_outlined : Icons.flip_camera_ios, color: iconColor, ),
            iconSize: 28.0,
            onPressed: _switchCameraAndSetState,
            tooltip: 'Wissel camera',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleDetection,
            errorBuilder: (context, error, child) {
               print('[Scanner] MobileScanner Error: $error');
               String errorMessage = 'Fout bij starten camera.';
               // Attempt to check for permission errors more reliably
               if (error.toString().toLowerCase().contains('permission') || error.toString().contains('CAMERA_ERROR')) {
                 errorMessage = 'Camera permissie geweigerd. Geef toegang in de app-instellingen.';
               }
               return Center(child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: Text(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
               ));
             },
            placeholderBuilder: (context, child) { return const Center(child: CircularProgressIndicator()); }
          ),
           // Visual overlay for the scan window
           Container(
             width: MediaQuery.of(context).size.width * 0.75,
             height: MediaQuery.of(context).size.height * 0.3,
             decoration: BoxDecoration(
               border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
               borderRadius: BorderRadius.circular(12),
             ),
           )
        ]
      ),
    );
  }
} // <<< EINDE _ScannerScreenState