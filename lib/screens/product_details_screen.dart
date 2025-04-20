// lib/screens/product_details_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'dart:convert';
import 'dart:async';

import '../models/product.dart';
import 'scanner_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String? _description; String? _specifications; String? _detailImageUrl; String? _detailPriceString; String? _detailsError; bool _isLoadingStock = true; Map<String, int?> _storeStocks = {}; String? _stockError;
  String? _detailOldPriceString; String? _detailDiscountLabel; String? _detailPromotionDescription; String? _detailPricePerUnitString; // Nieuwe state
  bool _isLoadingDetails = true;
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'; final Map<String, String> _targetStores = { 'Gamma Haarlem': '39', 'Gamma Velserbroek': '858', 'Gamma Cruquius': '669', 'Gamma Hoofddorp': '735', 'Gamma Heemskerk': '857', 'Karwei Haarlem': '647', 'Karwei Haarlem-Zuid': '844', };
  final String gammaStockApiBase = 'https://api.gamma.nl/stock/2/'; final String karweiStockApiBase = 'https://api.karwei.nl/stock/2/'; final String gammaCookieName = 'PREFERRED-STORE-UID'; final String gammaCookieValueHaarlem = '39';

  @override
  void initState() {
    super.initState();
    _detailImageUrl = widget.product.imageUrl;
    _detailPriceString = widget.product.priceString;
    _detailOldPriceString = widget.product.oldPriceString;
    _detailDiscountLabel = widget.product.discountLabel;
    _detailPromotionDescription = widget.product.promotionDescription;
    _detailPricePerUnitString = widget.product.pricePerUnitString; // Initialiseer
    _fetchProductDetails();
    _fetchSpecificStoreStocks();
  }

  // --- PARSER AANGEPAST MET PRIJS PER STUK ---
  Future<void> _fetchProductDetails() async {
    setState(() { _isLoadingDetails = true; _description = null; _specifications = null; _detailsError = null; });
    if (widget.product.productUrl == null) { setState(() { _detailsError = "URL?"; _isLoadingDetails = false; }); return; }
    final url = Uri.parse(widget.product.productUrl!); print('[Parser Details] Fetching: $url');
    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent}); if (!mounted) return;
      if (response.statusCode == 200) {
        final document = parse(response.body); String? pDesc; String? pSpecs; String? fImgUrl = _detailImageUrl; String? newPrice; String? newOldPrice; String? newDiscount; String? newPromoDesc;
        String? newPricePerUnit; // Nieuwe var

        // Description & Specs
        final infoEl = document.querySelector('#product-info-content'); if (infoEl != null) { String short = infoEl.querySelectorAll('div.product-info-short ul li').map((li) => '• ${li.text.trim()}').join('\n'); final descEl = infoEl.querySelector('div.description div[itemprop="description"] p') ?? infoEl.querySelector('div.description p'); String main = descEl?.text.trim() ?? ''; List<String> parts = []; if (short.isNotEmpty) parts.add(short); if (main.isNotEmpty) parts.add(main); pDesc = parts.join('\n\n').trim(); if (pDesc.isEmpty) pDesc = null; }
        final specsEl = document.querySelector('#product-specs'); if (specsEl != null) { final List<String> lines = []; final tables = specsEl.querySelectorAll('table.fancy-table'); if (tables.isNotEmpty) { for (var t in tables) { final h = t.querySelector('thead tr.group-name th strong'); if (h != null) { if (lines.isNotEmpty) lines.add(''); lines.add('${h.text.trim()}:'); } final rows = t.querySelectorAll('tbody tr'); for (var r in rows) { final kE = r.querySelector('th.attrib'); final vE = r.querySelector('td.value .feature-value'); if (kE != null && vE != null) { final k = kE.text.trim(); final v = vE.text.trim(); if (k.isNotEmpty) lines.add('  $k: $v'); } } } pSpecs = lines.join('\n').trim(); if (pSpecs.isEmpty) pSpecs = 'Specs leeg.'; } else { pSpecs = 'Geen specs tabel.'; } } else { pSpecs = 'Specs niet gevonden.'; }
        final imgEl = document.querySelector('img.product-main-image'); if (imgEl != null) { String? dS = imgEl.attributes['data-src']; String? s = imgEl.attributes['src']; String? tmp = dS ?? s; if (tmp != null && tmp.contains('/placeholders/')) { String? alt = (tmp == dS) ? s : dS; if (alt != null && !alt.contains('/placeholders/')) { tmp = alt; } else { tmp = null; } } if (tmp != null && !tmp.startsWith('http')) tmp = null; if (tmp != null) fImgUrl = tmp; } else { final metaImg = document.querySelector('meta[itemprop="image"]'); String? mUrl = metaImg?.attributes['content']; if (mUrl != null && mUrl.startsWith('http')) fImgUrl = mUrl; }

        // Prijs Parsing
        newPrice = document.querySelector('meta[itemprop="price"]')?.attributes['content']?.trim(); newOldPrice = document.querySelector('.product-price-base .before-price')?.text.trim() ?? document.querySelector('.pdp-price__retail .price-amount')?.text.trim() ?? document.querySelector('.price-suggested .price-amount')?.text.trim() ?? document.querySelector('span[data-price-type="oldPrice"] .price')?.text.trim();
        if (newPrice == null || newPrice.isEmpty) { final priceElement = document.querySelector('.price-sales-standard .price-amount') ?? document.querySelector('.pdp-price__integer'); final decimalElement = document.querySelector('.pdp-price__fractional'); if (priceElement != null && decimalElement == null) { newPrice = priceElement.text.trim().replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.'); } else if (priceElement != null && decimalElement != null) { final intP = priceElement.text.trim(); final decP = decimalElement.text.trim(); if (intP.isNotEmpty && decP.isNotEmpty) { newPrice = '$intP.$decP'; } } }
        if (newOldPrice != null) { newOldPrice = newOldPrice.replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.'); if (newOldPrice.isEmpty) newOldPrice = null; }
        if (newOldPrice != null && newPrice == null) { newPrice = _detailPriceString; }

        // Discount Label Parsing
        final promoInfoLabel = document.querySelector('.promotion-info-label div div'); if (promoInfoLabel != null) { newDiscount = promoInfoLabel.text.trim(); } else { newDiscount = document.querySelector('.product-labels .label-item')?.text.trim() ?? document.querySelector('.sticker-action')?.text.trim() ?? document.querySelector('.product-badge .badge-text')?.text.trim(); } if (newDiscount != null && newDiscount.isEmpty) newDiscount = null; if (newDiscount == null && newOldPrice != null && newPrice != null && newOldPrice != newPrice) { newDiscount = "Actie"; }

        // Promotion Description Parsing
        final promoDescElement = document.querySelector('dd.promotion-info-description'); if (promoDescElement != null) { newPromoDesc = promoDescElement.text.trim().replaceAll(RegExp(r'Bekijk alle producten.*$', multiLine: true), '').replaceAll(RegExp(r'\s+'), ' ').trim(); if (newPromoDesc.isEmpty) newPromoDesc = null; }

        // Prijs per Eenheid Parsing
        final pricePerUnitElement = document.querySelector('.product-price-per-unit span:last-child');
        if (pricePerUnitElement != null) { newPricePerUnit = pricePerUnitElement.text.trim().replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.'); if (newPricePerUnit.isEmpty || newPricePerUnit == newPrice) newPricePerUnit = null; } // Zet null als gelijk aan hoofd prijs

        if(mounted){setState((){_description=pDesc;_specifications=pSpecs;_detailImageUrl=fImgUrl;if(newPrice!=null&&newPrice.isNotEmpty)_detailPriceString=newPrice;_detailOldPriceString=newOldPrice;_detailDiscountLabel=newDiscount;_detailPromotionDescription=newPromoDesc;_detailPricePerUnitString = newPricePerUnit; _detailsError=(_description==null&&_specifications==null)?'Kon details niet laden.':null;});}
      } else { if (mounted) setState(() { _detailsError = 'Fout details: ${response.statusCode}'; }); }
    } catch (e) { print('[Parser Details] Error: $e'); if (mounted) setState(() { _detailsError = 'Fout verwerken: $e'; }); }
    finally { if (mounted) { setState(() { _isLoadingDetails = false; }); } }
  }
  // --- EINDE PARSER AANPASSING ---

  Future<void> _fetchSpecificStoreStocks() async {
    setState(() { _isLoadingStock = true; _stockError = null; _storeStocks = {}; }); String pId = widget.product.articleCode; if (pId == 'Code niet gevonden') { setState(() { _stockError = "Code?"; _isLoadingStock = false; }); return; } else { try { pId = int.parse(pId).toString(); } catch (e) {} } Map<String, int?> stocks = {}; String err = ''; final gEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma')); final kEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei')); final gParam = gEntries.map((e) => 'Stock-${e.value}-${pId}').join(','); final kParam = kEntries.map((e) => 'Stock-${e.value}-${pId}').join(','); List<Future<void>> calls = [];
    if (gParam.isNotEmpty) { final url = Uri.parse('$gammaStockApiBase?uids=$gParam'); final h = {'User-Agent': _userAgent, 'Origin':'https://www.gamma.nl', 'Referer':'https://www.gamma.nl/', 'Cookie':'$gammaCookieName=$gammaCookieValueHaarlem'}; calls.add( http.get(url, headers:h).then((r) { if(r.statusCode==200){try{final d=jsonDecode(r.body) as List;for(var e in gEntries){final u='Stock-${e.value}-${pId}';var s=d.firstWhere((i)=>i is Map&&i['uid']==u, orElse:()=>null);if(s!=null){final q=s['quantity'];stocks[e.key]=(q is int)?q:((q is String)?int.tryParse(q):null);}else{stocks[e.key]=null;}}}catch(e){err+=' G P.';print("G Stock Parse Err: $e");}}else{err+=' G(${r.statusCode}).';}}).catchError((e){err+=' G N.';print("G Stock Net Err: $e");}) ); }
    if (kParam.isNotEmpty) { final url = Uri.parse('$karweiStockApiBase?uids=$kParam'); final h = {'User-Agent': _userAgent, 'Origin':'https://www.karwei.nl', 'Referer':'https://www.karwei.nl/'}; calls.add( http.get(url, headers:h).then((r) { if(r.statusCode==200){try{final d=jsonDecode(r.body) as List;for(var e in kEntries){final u='Stock-${e.value}-${pId}';var s=d.firstWhere((i)=>i is Map&&i['uid']==u, orElse:()=>null);if(s!=null){final q=s['quantity'];stocks[e.key]=(q is int)?q:((q is String)?int.tryParse(q):null);}else{stocks[e.key]=null;}}}catch(e){err+=' K P.';print("K Stock Parse Err: $e");}}else{err+=' K(${r.statusCode}).';}}).catchError((e){err+=' K N.';print("K Stock Net Err: $e");}) ); }
    await Future.wait(calls); if (mounted) { setState(() { _storeStocks = stocks; _stockError = err.isEmpty ? null : err.trim(); _isLoadingStock = false; }); }
  }

  Future<void> _navigateToScannerFromDetails() async { try { final String? scanResult = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const ScannerScreen()),); if (!mounted) return; if (scanResult != null && scanResult.isNotEmpty) { print("[Details Nav] Scan resultaat: $scanResult"); String? resultValueForHomePage; final Uri? uri = Uri.tryParse(scanResult); final bool isLikelyUrl = uri != null && uri.hasScheme && uri.hasAuthority; final bool isGammaProductUrl = isLikelyUrl && uri.host.endsWith('gamma.nl') && uri.pathSegments.contains('assortiment') && uri.pathSegments.contains('p') && uri.pathSegments.last.isNotEmpty; final bool isEan13 = RegExp(r'^[0-9]{13}$').hasMatch(scanResult); if (isGammaProductUrl) { print("[Details Nav] Gamma URL."); String pIdRaw = uri.pathSegments.last; String sId = pIdRaw; if (pIdRaw.isNotEmpty && (pIdRaw.startsWith('B') || pIdRaw.startsWith('b')) && pIdRaw.length > 1) { sId = pIdRaw.substring(1); print("[Details Nav] Filtered ID: $sId"); } else { print("[Details Nav] Extracted ID (no B): $sId"); } try { sId = int.parse(sId).toString(); print("[Details Nav] Cleaned ID: $sId"); } catch(e) { print("[Details Nav] Int parse failed: $e"); } resultValueForHomePage = sId; } else if (isEan13) { print("[Details Nav] EAN13."); resultValueForHomePage = scanResult; } else { print("[Details Nav] Unknown format."); resultValueForHomePage = scanResult; ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Onbekend format: $scanResult')), ); } if (mounted) { Navigator.pop(context, resultValueForHomePage); } } else { print("Scanner closed."); } } catch (e) { if (!mounted) return; print("Scanner Err details: $e"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanner Fout: $e')),); } }

  void _showPromotionDetails(BuildContext context) {
    if (_detailPromotionDescription == null || _detailPromotionDescription!.isEmpty) return;
    showDialog( context: context, builder: (BuildContext context) {
      return AlertDialog( title: Text(_detailDiscountLabel ?? "Actie Details"), content: SingleChildScrollView( child: Text(_detailPromotionDescription!), ),
        actions: <Widget>[ TextButton( child: const Text('Sluiten'), onPressed: () => Navigator.of(context).pop(), ), ], ); }, );
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme; final clr = Theme.of(context).colorScheme; final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isDiscountChipTappable = _detailPromotionDescription != null && _detailPromotionDescription!.isNotEmpty;

    return Scaffold(
      appBar: AppBar( title: Text(widget.product.title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis), actions: [ IconButton(icon: const Icon(Icons.qr_code_scanner_outlined), onPressed: _navigateToScannerFromDetails, tooltip: 'Scan nieuwe code'), ], ),
      body: SingleChildScrollView( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Afbeelding
          if (_detailImageUrl != null) Center(child: Padding(padding: const EdgeInsets.only(bottom: 20.0), child: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(_detailImageUrl!, height: 250, fit: BoxFit.contain, loadingBuilder: (ctx, child, p) => p == null ? child : Container(height: 250, alignment: Alignment.center, child: CircularProgressIndicator(value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null)), errorBuilder: (ctx, err, st) => Container(height: 250, color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.broken_image, size: 80, color: Colors.grey[400])), ),),),)
          else if (_isLoadingStock && _detailImageUrl == null) Container(height: 250, alignment: Alignment.center, child: const CircularProgressIndicator())
          else Container(height: 250, color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey[400])),

          // Titel & Codes
          Text(widget.product.title, style: txt.headlineSmall), const SizedBox(height: 8),
          Row(children: [ Icon(Icons.inventory_2_outlined, size: 16, color: txt.bodySmall?.color), const SizedBox(width: 4), Text('Art: ${widget.product.articleCode}', style: txt.bodyLarge), const SizedBox(width: 16), if (widget.product.eanCode != null) ...[ Icon(Icons.barcode_reader, size: 16, color: txt.bodySmall?.color), const SizedBox(width: 4), Text(widget.product.eanCode!, style: txt.bodyMedium?.copyWith(color: txt.bodySmall?.color)), ], ],),
          if (widget.product.productUrl != null) ...[ const SizedBox(height: 12), SelectableText(widget.product.productUrl!, style: txt.bodySmall?.copyWith(color: clr.primary)), ],
          const SizedBox(height: 16),

          // --- Prijs Sectie (Aangepast met prijs per stuk) ---
          Row( crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (_isLoadingDetails && _detailPriceString == null) Text("Prijs laden...", style: txt.titleLarge?.copyWith(color: Colors.grey))
              else if (_detailPriceString != null)
                 RichText( text: TextSpan( style: txt.headlineSmall?.copyWith(color: clr.onSurface), children: [ // Gebruik headlineSmall als basis
                       if (_detailOldPriceString != null) TextSpan( text: '€ $_detailOldPriceString  ', style: TextStyle( fontSize: txt.titleMedium?.fontSize ?? 16, decoration: TextDecoration.lineThrough, color: Colors.grey[600],), ),
                       TextSpan( text: '€ $_detailPriceString', style: TextStyle( color: clr.primary, fontWeight: FontWeight.bold,),),
                       // Toon /m² alleen als er OOK een prijs per stuk is die anders is
                       if (_detailPricePerUnitString != null && _detailPriceString != _detailPricePerUnitString)
                         TextSpan( text: ' /m²', style: txt.bodySmall?.copyWith(color: clr.onSurface.withOpacity(0.6)) )
                     ],),)
              else Text('Prijs?', style: txt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),),
              const SizedBox(width: 12),
              // Kortingslabel
              if (_detailDiscountLabel != null)
                 Flexible( child: Tooltip( message: isDiscountChipTappable ? "Bekijk details" : "", child: GestureDetector( onTap: isDiscountChipTappable ? () => _showPromotionDetails(context) : null, child: Chip( label: Row( mainAxisSize: MainAxisSize.min, children: [ Text(_detailDiscountLabel!, overflow: TextOverflow.ellipsis), if(isDiscountChipTappable) Padding( padding: const EdgeInsets.only(left: 4.0), child: Icon(Icons.info_outline, size: txt.labelSmall?.fontSize ?? 12, color: isDarkMode ? Colors.black54 : clr.onErrorContainer.withOpacity(0.7)), ) ],), labelStyle: txt.labelSmall?.copyWith(color: isDarkMode ? Colors.black : clr.onErrorContainer, fontWeight: isDarkMode ? FontWeight.bold : FontWeight.normal,), backgroundColor: isDarkMode ? Colors.orange[700] : clr.errorContainer, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(4.0), side: BorderSide.none, ), ),),),),
           ], ),
           // Toon prijs per stuk apart indien beschikbaar en anders
           if (_detailPricePerUnitString != null && _detailPriceString != _detailPricePerUnitString)
              Padding(
                 padding: const EdgeInsets.only(top: 4.0),
                 child: Text(
                    '€ $_detailPricePerUnitString per stuk', // Haal 'stuk' evt. uit HTML
                    style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                 ),
              ),
          const SizedBox(height: 16),
          // --- Einde Prijs Sectie ---

          // Voorraad Sectie
          const Divider(thickness: 0.5),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Text('Voorraad (indicatie)', style: txt.titleLarge?.copyWith(fontSize: 18)),),
          _buildStoreStockSection(context, txt),
          const Divider(height: 32, thickness: 0.5),

          // Details Sectie
          _buildDetailsSection(context, txt),
        ],
      ),),
    ); // Einde Scaffold
  }

  Widget _buildStoreStockSection(BuildContext context, TextTheme textTheme) {
    if (_isLoadingStock) { return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2.0))); }
    List<Widget> children = []; if (_stockError != null) { children.add( Center( child: Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Text( _stockError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), )); }
    if (_storeStocks.isEmpty && _stockError == null) { children.add(Center( child: Padding( padding: const EdgeInsets.all(8.0), child: Text( "Kon geen voorraad vinden.", style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic), textAlign: TextAlign.center, ), ), ));
    } else {
      final sorted = _storeStocks.entries.toList()..sort((a,b){bool aH=a.key=='Gamma Haarlem';bool bH=b.key=='Gamma Haarlem';if(aH)return -1;if(bH)return 1;bool aG=a.key.startsWith('Gamma');bool bG=b.key.startsWith('Gamma');if(aG&&!bG)return -1;if(!aG&&bG)return 1;return a.key.compareTo(b.key);});
       for (var e in sorted) {
        final sN = e.key; final sC = e.value; final iH = sN=='Gamma Haarlem'; IconData i; Color c; String t;
        if (sC == null) { i = Icons.help_outline; c = Colors.grey; t = "Niet in assortiment?"; }
        else if (sC > 5) { i = Icons.check_circle_outline; c = Colors.green; t = "$sC stuks"; }
        else if (sC > 0) { i = Icons.warning_amber_outlined; c = Colors.orange; t = "$sC stuks (laag)"; }
        else { i = Icons.cancel_outlined; c = Colors.red; t = "Niet op voorraad"; }
        children.add( Padding( padding: const EdgeInsets.symmetric(vertical: 5.0), child: Row( children: [ Icon(i, color: c, size: 18), const SizedBox(width: 8), Expanded(child: Text( sN, style: textTheme.bodyMedium?.copyWith( fontWeight: iH ? FontWeight.bold : FontWeight.normal ) )), Text(t, style: textTheme.bodyMedium?.copyWith(color: c, fontWeight: FontWeight.w500)), ], ), ) );
      }
    }
    return Column(children: children);
  }

  Widget _buildDetailsSection(BuildContext context, TextTheme textTheme) {
    final clr = Theme.of(context).colorScheme;
     if (_isLoadingDetails || (_isLoadingStock && _description == null && _specifications == null)) { return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(), )); }
     else if (_detailsError != null && _description == null && _specifications == null) { return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Text( _detailsError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), ); }
     else { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
           if(_detailsError != null && (_description != null || _specifications != null)) Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Text("Opmerking: $_detailsError", style: TextStyle(color: Colors.orange[800], fontStyle: FontStyle.italic)), ),
           if (_description != null && _description!.isNotEmpty) ...[ Text('Omschrijving', style: textTheme.titleLarge?.copyWith(fontSize: 18)), const SizedBox(height: 8), SelectableText(_description!, style: textTheme.bodyMedium?.copyWith(height: 1.5)), const SizedBox(height: 24), const Divider(thickness: 0.5), const SizedBox(height: 24), ]
           else if (!_isLoadingDetails && _detailsError == null) ...[ Text('Omschrijving niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)), const SizedBox(height: 24), ],
           if (_specifications != null && !_specifications!.contains('niet gevonden') && !_specifications!.contains('leeg') && _specifications!.isNotEmpty) ...[ Text('Specificaties', style: textTheme.titleLarge?.copyWith(fontSize: 18)), const SizedBox(height: 8), Container( width: double.infinity, padding: const EdgeInsets.all(12.0), decoration: BoxDecoration( color: clr.surfaceContainerHighest.withAlpha((255*.3).round()), borderRadius: BorderRadius.circular(4.0), ), child: SelectableText( _specifications!, style: textTheme.bodyMedium?.copyWith(height: 1.6, fontFamily: 'monospace'), ) ), ]
           else if (!_isLoadingDetails && _detailsError == null) ...[ Text('Specificaties niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)), ],
         ], ); }
  }
} // <<< EINDE _ProductDetailsScreenState