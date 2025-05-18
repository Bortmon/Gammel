import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'dart:async';
import 'dart:convert';

import '../models/login_result.dart';
import '../models/product.dart';
import 'product_details/product_details_screen.dart';
import 'schedule_screen.dart';
import 'scanner_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class HomePage extends StatefulWidget
{
  final bool isLoggedIn;
  final String? authToken;
  final String? employeeId;
  final String? nodeId;
  final String? userName;
  final Future<LoginResult> Function(BuildContext context) loginCallback;
  final Future<void> Function() logoutCallback;

  const HomePage(
  {
    super.key,
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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  String _lastSearchTerm = '';

  late TabController _tabController;
  final String _filterStoreIdHaarlem = '39';
  final String _filterStoreNameHaarlem = 'Haarlem';
  int _activeTabIndex = 0;

  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  final RegExp _ean13Regex = RegExp(r'^[0-9]{13}$');
  final RegExp _priceCleanRegex = RegExp(r'[^\d,.]');
  final RegExp _promoDescCleanupRegex1 = RegExp(r'Bekijk alle producten.*$', multiLine: true);
  final RegExp _promoDescCleanupRegex2 = RegExp(r'\s+');

  @override
  void initState()
  {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return; 
      }
      if (mounted) {
        final newIndex = _tabController.index;
        if (_activeTabIndex != newIndex) {
          setState(() {
            _activeTabIndex = newIndex;
            _products = []; 
            _error = null;
          });
          if (_searchController.text.isNotEmpty) {
            _searchProducts(_searchController.text);
          }
        }
      }
    });
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onBottomNavTabSelected(BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.agenda:
        _navigateToScheduleScreen(context);
        break;
      case BottomNavTab.zaagtool:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const UnderConstructionScreen(pageName: "Zaagplan")));
        break;
      case BottomNavTab.scanner:
        _navigateToScanner();
        break;
    }
  }

  Future<void> _navigateToScanner() async
  {
    try
    {
      final String? scanResultFromScanner = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const ScannerScreen()),
      );

      if (!mounted) return;

      if (scanResultFromScanner != null && scanResultFromScanner.isNotEmpty)
      {
        String? searchTermForProducts;
        final Uri? uri = Uri.tryParse(scanResultFromScanner);
        final bool isLikelyUrl = uri != null && uri.hasScheme && uri.hasAuthority;
        final bool isGammaProductUrl = isLikelyUrl &&
            uri.host.endsWith('gamma.nl') &&
            uri.pathSegments.contains('assortiment') &&
            uri.pathSegments.contains('p') &&
            uri.pathSegments.last.isNotEmpty;
        final bool isEan13 = _ean13Regex.hasMatch(scanResultFromScanner);

        if (isGammaProductUrl)
        {
           String productIdRaw = uri.pathSegments.last;
           String searchId = productIdRaw;
           if (productIdRaw.isNotEmpty && (productIdRaw.startsWith('B') || productIdRaw.startsWith('b')) && productIdRaw.length > 1)
           {
             searchId = productIdRaw.substring(1);
           }
           try { searchId = int.parse(searchId).toString(); } catch(e) { /* no-op */ }
           searchTermForProducts = searchId;
        }
        else if (isEan13)
        {
           searchTermForProducts = scanResultFromScanner;
        }
        else
        {
           searchTermForProducts = scanResultFromScanner;
           if (mounted)
           {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Onbekend code formaat gescand: $scanResultFromScanner')),
            );
           }
        }

        if (searchTermForProducts != null) {
          _searchController.text = searchTermForProducts;
          if (_tabController.index != 0) {
            _tabController.animateTo(0);
          } else {
            _searchProducts(searchTermForProducts);
          }
        } else {
           setState(() {
             _products = [];
             _error = null;
           });
        }
      }
    }
    catch (e)
    {
      if (!mounted) return;
      setState(()
      {
        _error = "Fout bij openen scanner: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _searchProducts(String query) async
  {
    if (query.isEmpty)
    {
      setState(() {
        _products = [];
        _error = null;
        _lastSearchTerm = '';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(()
    {
      _isLoading = true;
      _error = null;
      _products = [];
      _lastSearchTerm = query;
    });

    String urlString = 'https://www.gamma.nl/assortiment/zoeken?text=${Uri.encodeComponent(query)}';
    bool isFilteredSearch = false;

    if (_activeTabIndex == 1) {
      urlString += '&f_storeUidAvailability=$_filterStoreIdHaarlem';
      isFilteredSearch = true;
    }

    final Uri url = Uri.parse(urlString);

    try
    {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;

      if (response.statusCode == 200)
      {
        final responseBody = utf8.decode(response.bodyBytes);
        final document = parse(responseBody);

        final List<Product> foundProducts = _parseProducts(document);
        setState(()
        {
          _products = foundProducts;
          if (_products.isEmpty && _lastSearchTerm.isNotEmpty)
          {
             _error = 'Geen producten gevonden voor "$_lastSearchTerm"${isFilteredSearch ? " (op voorraad in $_filterStoreNameHaarlem)" : ""}.';
          }
          _isLoading = false;
        });
      }
      else
      {
        setState(()
        {
          _error = 'Fout bij ophalen zoekresultaten: Status ${response.statusCode}';
          _isLoading = false;
        });
      }
    }
    catch (e)
    {
      if (!mounted) return;
      setState(()
      {
        _error = 'Fout tijdens zoeken: $e';
        _isLoading = false;
      });
    }
  }

 List<Product> _parseProducts(dom.Document document)
 {
    final products = <Product>[];
    final productElements = document.querySelectorAll('article.js-product-tile');

    for (final element in productElements)
    {
      String? imageUrl;
      String? priceString;
      String? oldPriceString;
      String? discountLabel;
      String title = 'Titel?';
      String articleCode = 'Code?';
      String? eanCode;
      String? productUrl;
      String? promotionDescription;
      String? pricePerUnitString;
      String? priceUnit;
      String? pricePerUnitLabel;

      try
      {
        title = element.querySelector('div.product-tile-name a')?.text.trim() ?? element.querySelector('a.click-mask')?.attributes['title']?.trim() ?? 'Titel?';
        productUrl = element.querySelector('a.click-mask')?.attributes['href'];
        if (productUrl != null && !productUrl.startsWith('http'))
        {
          if (!productUrl.startsWith('/'))
          {
              productUrl = '/$productUrl';
          }
          productUrl = 'https://www.gamma.nl$productUrl';
        }
        articleCode = element.attributes['data-objectid']?.trim() ?? 'Code?';
        if (articleCode != 'Code?' && articleCode.isNotEmpty && articleCode.length > 1)
        {
          if (int.tryParse(articleCode.substring(0, 1)) == null)
          {
            articleCode = articleCode.substring(1);
          }
        }
        eanCode = element.attributes['data-ean']?.trim();
        if (articleCode == 'Code?' && eanCode != null)
        {
          articleCode = eanCode;
          eanCode = null;
        }
        else if (eanCode == null || eanCode.isEmpty)
        {
          eanCode = null;
        }

        final imageContainer = element.querySelector('div.product-tile-image');
        if (imageContainer != null)
        {
          final imageElement = imageContainer.querySelector('img:not(.sticker)');
          if (imageElement != null)
          {
            imageUrl = imageElement.attributes['data-src'] ?? imageElement.attributes['src'];
          }
          else
          {
            final fallbackImageElement = imageContainer.querySelector('img');
            imageUrl = fallbackImageElement?.attributes['data-src'] ?? fallbackImageElement?.attributes['src'];
          }
          if (imageUrl != null && !imageUrl.startsWith('http')) imageUrl = null;
        }

        final priceContainer = element.querySelector('.product-price-container');
        if (priceContainer != null)
        {
             final priceElement = priceContainer.querySelector('.product-tile-price .product-tile-price-current');
             final decimalElement = priceContainer.querySelector('.product-tile-price .product-tile-price-decimal');
             if (priceElement != null && decimalElement != null)
             {
               String intPart = priceElement.text.trim().replaceAll('.', '');
               String decPart = decimalElement.text.trim();
               if (intPart.isNotEmpty && decPart.isNotEmpty)
               {
                   priceString = '$intPart.$decPart';
               }
             }
             if (priceString == null)
             {
                 priceString = element.attributes['data-price']?.trim();
             }

             final priceUnitElement = priceContainer.querySelector('.product-tile-price .product-tile-price-unit');
             if (priceUnitElement != null)
             {
               String tempUnit = priceUnitElement.text.trim();
               if (tempUnit.isNotEmpty)
               {
                   priceUnit = tempUnit.replaceAll('m²', 'm2');
               }
             }

             final oldPriceElem = priceContainer.querySelector('.product-tile-price-old .before-price') ?? priceContainer.querySelector('.product-tile-price-old span.before-price') ?? priceContainer.querySelector('span.product-tile-price-old');
             if (oldPriceElem != null)
             {
               String tempOldPriceText = oldPriceElem.text.trim();
               if (tempOldPriceText.isNotEmpty)
               {
                 oldPriceString = tempOldPriceText.replaceAll(_priceCleanRegex, '').replaceFirst(',', '.');
                 if (oldPriceString.isEmpty || oldPriceString == priceString)
                 {
                     oldPriceString = null;
                 }
                 String? parentText = oldPriceElem.parent?.text;
                 if (oldPriceString != null && priceUnit == null && parentText != null && parentText.contains('m²'))
                 {
                   priceUnit = '/m2';
                 }
               }
             }

             final pricePerUnitElement = priceContainer.querySelector('.product-price-per-unit span:last-child');
              if (pricePerUnitElement != null)
              {
                  String tempPPU = pricePerUnitElement.text.trim();
                  if (tempPPU.isNotEmpty)
                  {
                      pricePerUnitString = tempPPU.replaceAll(_priceCleanRegex, '').replaceFirst(',', '.');
                      if (pricePerUnitString.isEmpty) pricePerUnitString = null;
                  }
              }
             final pricePerUnitLabelElement = priceContainer.querySelector('.product-price-per-unit span:first-child');
             if (pricePerUnitLabelElement != null)
             {
               pricePerUnitLabel = pricePerUnitLabelElement.text.trim();
               if (pricePerUnitLabel.isEmpty) pricePerUnitLabel = null;
             }

             discountLabel = priceContainer.querySelector('.promotion-text-label')?.text.trim();
             if (discountLabel == null || discountLabel.isEmpty)
             {
               final sticker = element.querySelector('span.sticker.promo, img.sticker.promo');
               if (sticker != null)
               {
                   discountLabel = sticker.attributes['alt']?.trim();
               }
             }
             if (discountLabel == null || discountLabel.isEmpty)
             {
               final badge = element.querySelector('.product-tile-badge');
               if (badge != null)
               {
                   discountLabel = badge.text.trim();
               }
             }
             if (discountLabel == null || discountLabel.isEmpty)
             {
               final loyaltyLabel = priceContainer.querySelector('div.product-loyalty-label') ?? element.querySelector('dt.product-loyalty-label');
               if (loyaltyLabel != null && loyaltyLabel.text.contains("Voordeelpas"))
               {
                 discountLabel = "Voordeelpas";
                 final promoLabelDiv = element.querySelector('dt.promotion-info-label div div');
                 if (promoLabelDiv != null)
                 {
                   String promoText = promoLabelDiv.text.trim();
                   if(promoText.isNotEmpty) discountLabel = promoText;
                 }
               }
             }

             final promoDescElement = priceContainer.querySelector('.promotion-info-description') ?? element.querySelector('dd.promotion-info-description');
             if (promoDescElement != null)
             {
                 promotionDescription = promoDescElement.text.trim()
                    .replaceAll(_promoDescCleanupRegex1, '')
                    .replaceAll(_promoDescCleanupRegex2, ' ')
                    .trim();
                 if (promotionDescription.isEmpty) promotionDescription = null;
             }

             if (discountLabel == null && oldPriceString != null && priceString != null && oldPriceString != priceString)
             {
               discountLabel = "Actie";
             }
        }
        else
        {
          priceString = element.attributes['data-price']?.trim();
        }

        if (discountLabel != null && discountLabel.isEmpty) discountLabel = null;

        if (title != 'Titel?' && articleCode != 'Code?')
        {
          products.add(Product(
            title: title,
            articleCode: articleCode,
            eanCode: eanCode,
            imageUrl: imageUrl,
            productUrl: productUrl,
            priceString: priceString,
            priceUnit: priceUnit,
            oldPriceString: oldPriceString,
            discountLabel: discountLabel,
            promotionDescription: promotionDescription,
            pricePerUnitString: pricePerUnitString,
            pricePerUnitLabel: pricePerUnitLabel,
          ));
        }
      }
      catch (e, s)
      {
        print("[Parser Results] Error parsing product tile: $e\nStack: $s");
      }
    }
    return products;
  }

  Future<void> _navigateToDetails(BuildContext context, Product product) async
  {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)),
    );
    if (mounted && result != null && result.isNotEmpty)
    {
      _searchController.text = result;
       if (_tabController.index != 0) {
        _tabController.animateTo(0);
      } else {
        _searchProducts(result);
      }
    }
  }

  void _navigateToScheduleScreen(BuildContext context)
  {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScheduleScreen(
          authToken: widget.authToken,
          isLoggedIn: widget.isLoggedIn,
          employeeId: widget.employeeId,
          nodeId: widget.nodeId,
          userName: widget.userName,
          loginCallback: widget.loginCallback,
          logoutCallback: widget.logoutCallback,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final ColorScheme clr = Theme.of(context).colorScheme;
    final TextTheme txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: clr.background,
      appBar: AppBar(
        title: const Text('Gammel'),
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight - 8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
                color: clr.surface.withAlpha(200),
                borderRadius: BorderRadius.circular(10.0)
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: clr.primary.withAlpha((0.25 * 255).round())
              ),
              indicatorPadding: const EdgeInsets.all(4.0),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: clr.primary,
              labelStyle: txt.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14.5),
              unselectedLabelColor: clr.onSurface.withAlpha((0.7 * 255).round()),
              unselectedLabelStyle: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 14.5),
              tabs: [
                const Tab(text: 'Algemeen'),
                Tab(text: _filterStoreNameHaarlem),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: Column(
          children:
          [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextField(
                 controller: _searchController,
                style: txt.bodyLarge?.copyWith(color: clr.onSurface),
                decoration: InputDecoration(
                  hintText: 'Zoek product of scan barcode',
                  hintStyle: txt.bodyLarge?.copyWith(color: clr.onSurface.withAlpha(150)),
                  prefixIcon: Icon(Icons.search, color: clr.onSurface.withAlpha(200), size: 26),
                  fillColor: clr.surface, 
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 18.0), 
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0), 
                    borderSide: BorderSide(color: clr.outline.withAlpha(80), width: 1.0), 
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: clr.primary, width: 2.0),
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child)
                    {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: clr.onSurface.withAlpha(200)),
                              tooltip: 'Wissen',
                              onPressed: ()
                              {
                                _searchController.clear();
                                setState(()
                                {
                                  _products = [];
                                  _error = null;
                                  _lastSearchTerm = '';
                                });
                              },
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
                onSubmitted: _searchProducts,
               ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildResultsArea(),
                  _buildResultsArea(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        onTabSelected: _onBottomNavTabSelected,
      ),
    );
  }

  Widget _buildProductListItem(BuildContext context, Product product)
  {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _navigateToDetails(context, product),
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: clr.surface,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
          [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: clr.background,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: product.imageUrl != null
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, pr) => pr == null
                        ? child
                        : Center(child: CircularProgressIndicator(strokeWidth: 2.0, value: pr.expectedTotalBytes != null ? pr.cumulativeBytesLoaded / pr.expectedTotalBytes! : null, color: clr.primary)),
                      errorBuilder: (ctx, err, st) => Center(child: Icon(Icons.broken_image_outlined, color: clr.onSurface.withAlpha(100), size: 35)),
                    )
                  : Center(child: Icon(Icons.image_not_supported_outlined, color: clr.onSurface.withAlpha(100), size: 35)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                [
                  Text(
                    product.title,
                    style: txt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: clr.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Art: ${product.articleCode}',
                    style: txt.bodySmall?.copyWith(color: clr.onSurface.withAlpha(180)),
                  ),
                  if (product.eanCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        'EAN: ${product.eanCode}',
                        style: txt.bodySmall?.copyWith(color: clr.onSurface.withAlpha(160)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children:
                    [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.oldPriceString != null)
                            Text(
                              '€${product.oldPriceString}${product.priceUnit ?? ""}',
                              style: txt.bodyMedium?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: clr.onSurface.withAlpha(150),
                                fontSize: 13,
                              ),
                            ),
                          if (product.priceString != null)
                            Text(
                              '€${product.priceString}',
                              style: txt.headlineSmall?.copyWith(
                                color: clr.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text('Prijs onbekend', style: txt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: clr.onSurface.withAlpha(150))),

                          if (product.pricePerUnitString != null && product.priceString != product.pricePerUnitString)
                             Padding(
                               padding: const EdgeInsets.only(top: 2.0),
                               child: Text(
                                 '(€${product.pricePerUnitString} ${product.pricePerUnitLabel ?? "p/st"})',
                                 style: txt.bodySmall?.copyWith(color: clr.onSurface.withAlpha(160), fontSize: 11),
                               ),
                             )
                          else if (product.priceUnit != null && product.priceString != null)
                             Padding(
                               padding: const EdgeInsets.only(top: 2.0),
                               child: Text(
                                 product.priceUnit!,
                                 style: txt.bodySmall?.copyWith(color: clr.onSurface.withAlpha(160), fontSize: 11),
                               ),
                             ),
                        ],
                      ),
                      if (product.discountLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: clr.primary,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            product.discountLabel!,
                            style: txt.labelSmall?.copyWith(
                              color: clr.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea()
  {
    final TextTheme txt = Theme.of(context).textTheme;
    final ColorScheme clr = Theme.of(context).colorScheme;

    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator());
    }
    else if (_error != null)
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _error!,
            style: TextStyle(color: clr.error, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        )
      );
    }
    else if (_products.isNotEmpty)
    {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 16.0),
        itemCount: _products.length,
        itemBuilder: (context, index)
        {
          return _buildProductListItem(context, _products[index]);
        },
      );
    }
    else
    {
       String message = _lastSearchTerm.isEmpty
            ? ''
            : 'Geen producten gevonden voor "$_lastSearchTerm"${_activeTabIndex == 1 ? " (op voorraad in $_filterStoreNameHaarlem)" : ""}.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: txt.bodyMedium,
          ),
        )
      );
    }
  }
}

class UnderConstructionScreen extends StatelessWidget {
  final String pageName;
  const UnderConstructionScreen({super.key, required this.pageName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pageName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text('$pageName is onder constructie!', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}