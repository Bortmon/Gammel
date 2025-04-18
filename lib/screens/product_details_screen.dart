// lib/screens/product_details_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'dart:convert';

import '../models/product.dart'; // Import model
import 'scanner_screen.dart';    // Import scanner screen

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String? _description;
  String? _specifications;
  String? _detailImageUrl;
  String? _detailPriceString;
  String? _detailsError;
  bool _isLoadingStock = true;
  Map<String, int?> _storeStocks = {};
  String? _stockError;

  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  final Map<String, String> _targetStores = {
    'Gamma Haarlem': '39', 'Gamma Velserbroek': '858', 'Gamma Cruquius': '669',
    'Gamma Hoofddorp': '735', 'Gamma Heemskerk': '857', 'Karwei Haarlem': '647',
    'Karwei Haarlem-Zuid': '844',
  };
  final String gammaStockApiBase = 'https://api.gamma.nl/stock/2/';
  final String karweiStockApiBase = 'https://api.karwei.nl/stock/2/';
  final String gammaCookieName = 'PREFERRED-STORE-UID';
  final String gammaCookieValueHaarlem = '39';

  @override
  void initState() {
    super.initState();
    _detailImageUrl = widget.product.imageUrl;
    _detailPriceString = widget.product.priceString;
    _fetchProductDetails();
    _fetchSpecificStoreStocks();
  }

  Future<void> _fetchProductDetails() async {
    setState(() { _description = null; _specifications = null; _detailsError = null; });
    if (widget.product.productUrl == null) {
      setState(() { _detailsError = "URL?"; });
      return;
    }
    final url = Uri.parse(widget.product.productUrl!);
    print('[Parser Details] Fetching: $url');
    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final document = parse(response.body);
        String? pDesc; String? pSpecs; String? fImgUrl = _detailImageUrl; String? potPrice = _detailPriceString;

        // Description Parsing
        final infoEl = document.querySelector('#product-info-content');
        if (infoEl != null) {
          String short = infoEl.querySelectorAll('div.product-info-short ul li').map((li) => '• ${li.text.trim()}').join('\n');
          final descEl = infoEl.querySelector('div.description div[itemprop="description"] p') ?? infoEl.querySelector('div.description p');
          String main = descEl?.text.trim() ?? '';
          List<String> parts = [];
          if (short.isNotEmpty) parts.add(short);
          if (main.isNotEmpty) parts.add(main);
          pDesc = parts.join('\n\n').trim();
          if (pDesc.isEmpty) pDesc = null;
        }

        // Specifications Parsing
        final specsEl = document.querySelector('#product-specs');
        if (specsEl != null) {
          final List<String> lines = [];
          final tables = specsEl.querySelectorAll('table.fancy-table');
          if (tables.isNotEmpty) {
            for (var t in tables) {
              final h = t.querySelector('thead tr.group-name th strong');
              if (h != null) { if (lines.isNotEmpty) lines.add(''); lines.add('${h.text.trim()}:'); }
              final rows = t.querySelectorAll('tbody tr');
              for (var r in rows) {
                final kE = r.querySelector('th.attrib');
                final vE = r.querySelector('td.value .feature-value');
                if (kE != null && vE != null) {
                  final k = kE.text.trim();
                  final v = vE.text.trim();
                  if (k.isNotEmpty) lines.add('  $k: $v');
                }
              }
            }
            pSpecs = lines.join('\n').trim();
            if (pSpecs.isEmpty) pSpecs = 'Specs leeg.';
          } else { pSpecs = 'Geen specs tabel.'; }
        } else { pSpecs = 'Specs niet gevonden.'; }

        // Image URL Parsing
        final imgEl = document.querySelector('img.product-main-image');
        if (imgEl != null) {
          String? dS = imgEl.attributes['data-src']; String? s = imgEl.attributes['src']; String? tmp = dS ?? s;
          if (tmp != null && tmp.contains('/placeholders/')) { String? alt = (tmp == dS) ? s : dS; if (alt != null && !alt.contains('/placeholders/')) { tmp = alt; } else { tmp = null; } }
          if (tmp != null && !tmp.startsWith('http')) tmp = null;
          if (tmp != null) fImgUrl = tmp;
        } else {
          final metaImg = document.querySelector('meta[itemprop="image"]');
          String? mUrl = metaImg?.attributes['content'];
          if (mUrl != null && mUrl.startsWith('http')) fImgUrl = mUrl;
        }

        // Price Parsing
        final priceMeta = document.querySelector('meta[itemprop="price"]');
        potPrice = priceMeta?.attributes['content']?.trim();
        if (potPrice == null || potPrice.isEmpty) { final priceEl = document.querySelector('.price-sales-standard'); potPrice = priceEl?.text.trim().replaceAll(RegExp(r'[^\d,.]'), '').replaceFirst(',', '.'); }
        if (potPrice == null || potPrice.isEmpty) { final intEl = document.querySelector('.pdp-price__integer'); final decEl = document.querySelector('.pdp-price__fractional'); final intP = intEl?.text.trim(); final decP = decEl?.text.trim(); if (intP != null && intP.isNotEmpty && decP != null && decP.isNotEmpty) { potPrice = '$intP.$decP'; } }

        // Update State
        if (mounted) {
          setState(() {
            _description = pDesc;
            _specifications = pSpecs;
            _detailImageUrl = fImgUrl;
            if (potPrice != null && potPrice.isNotEmpty) { _detailPriceString = potPrice; }
            if (_description != null || _specifications != null) { _detailsError = null; }
            else if (_detailsError == null) { _detailsError = 'Kon omschrijving/specs niet vinden.'; }
          });
        }
      } else {
        if (mounted) setState(() { _detailsError = 'Fout details: ${response.statusCode}'; });
      }
    } catch (e) {
      print('[Parser Details] Error: $e');
      if (mounted) setState(() { _detailsError = 'Fout verwerken: $e'; });
    }
  }

  Future<void> _fetchSpecificStoreStocks() async {
    setState(() { _isLoadingStock = true; _stockError = null; _storeStocks = {}; });
    String pId = widget.product.articleCode;
    if (pId == 'Code niet gevonden') { setState(() { _stockError = "Code?"; _isLoadingStock = false; }); return; }
    else { try { pId = int.parse(pId).toString(); } catch (e) {} }
    Map<String, int?> stocks = {}; String err = '';
    final gEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma'));
    final kEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei'));
    final gParam = gEntries.map((e) => 'Stock-${e.value}-$pId').join(',');
    final kParam = kEntries.map((e) => 'Stock-${e.value}-$pId').join(',');
    List<Future<void>> calls = [];

    // Gamma API Call
    if (gParam.isNotEmpty) {
      final url = Uri.parse('$gammaStockApiBase?uids=$gParam');
      final h = {'User-Agent': _userAgent, 'Origin': 'https://www.gamma.nl', 'Referer': 'https://www.gamma.nl/', 'Cookie': '$gammaCookieName=$gammaCookieValueHaarlem'};
      calls.add(http.get(url, headers: h).then((r) {
        if (r.statusCode == 200) {
          try {
            final d = jsonDecode(r.body) as List;
            for (var e in gEntries) {
              final u = 'Stock-${e.value}-$pId';
              var s = d.firstWhere((i) => i is Map && i['uid'] == u, orElse: () => null);
              if (s != null) { final q = s['quantity']; stocks[e.key] = (q is int) ? q : ((q is String) ? int.tryParse(q) : null); }
              else { stocks[e.key] = null; }
            }
          } catch (e) { err += ' G P.'; print("Gamma Stock Parse Err: $e"); }
        } else { err += ' G(${r.statusCode}).'; }
      }).catchError((e) { err += ' G N.'; print("Gamma Stock Network Err: $e"); }));
    }

    // Karwei API Call
    if (kParam.isNotEmpty) {
      final url = Uri.parse('$karweiStockApiBase?uids=$kParam');
      final h = {'User-Agent': _userAgent, 'Origin': 'https://www.karwei.nl', 'Referer': 'https://www.karwei.nl/'};
      calls.add(http.get(url, headers: h).then((r) {
        if (r.statusCode == 200) {
          try {
            final d = jsonDecode(r.body) as List;
            for (var e in kEntries) {
              final u = 'Stock-${e.value}-$pId';
              var s = d.firstWhere((i) => i is Map && i['uid'] == u, orElse: () => null);
              if (s != null) { final q = s['quantity']; stocks[e.key] = (q is int) ? q : ((q is String) ? int.tryParse(q) : null); }
              else { stocks[e.key] = null; }
            }
          } catch (e) { err += ' K P.'; print("Karwei Stock Parse Err: $e"); }
        } else { err += ' K(${r.statusCode}).'; }
      }).catchError((e) { err += ' K N.'; print("Karwei Stock Network Err: $e"); }));
    }

    await Future.wait(calls);
    if (mounted) {
      setState(() { _storeStocks = stocks; _stockError = err.isEmpty ? null : err.trim(); _isLoadingStock = false; });
    }
  }

  Future<void> _navigateToScannerFromDetails() async {
    try {
      final String? code = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const ScannerScreen()),);
      if (!mounted) return;
      if (code != null && code.isNotEmpty) {
        Navigator.pop(context, code);
      }
    } catch (e) {
      if (!mounted) return;
      print("Scanner Err details: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanner Fout: $e')),);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final clr = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.title, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner_outlined), onPressed: _navigateToScannerFromDetails, tooltip: 'Scan'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Afbeelding
            if (_detailImageUrl != null)
              Center(child: Padding(padding: const EdgeInsets.only(bottom: 20.0), child: ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.network(_detailImageUrl!, height: 250, fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, p) => p == null ? child : Container(height: 250, alignment: Alignment.center, child: CircularProgressIndicator(value: p.expectedTotalBytes != null ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null)),
                        errorBuilder: (ctx, err, st) => Container(height: 250, color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.broken_image, size: 80, color: Colors.grey[400])), ),),),)
            else if (_isLoadingStock && _detailImageUrl == null)
              Container(height: 250, alignment: Alignment.center, child: const CircularProgressIndicator())
            else
              Container(height: 250, color: clr.surfaceContainerHighest.withAlpha((255 * .3).round()), alignment: Alignment.center, child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey[400])),

            // Titel & Codes
            Text(widget.product.title, style: txt.headlineSmall),
            const SizedBox(height: 8),
            Row(children: [ Icon(Icons.inventory_2_outlined, size: 16, color: txt.bodySmall?.color), const SizedBox(width: 4), Text('Art: ${widget.product.articleCode}', style: txt.bodyLarge), const SizedBox(width: 16), if (widget.product.eanCode != null) ...[ Icon(Icons.barcode_reader, size: 16, color: txt.bodySmall?.color), const SizedBox(width: 4), Text(widget.product.eanCode!, style: txt.bodyMedium?.copyWith(color: txt.bodySmall?.color)), ], ],),
            if (widget.product.productUrl != null) ...[ const SizedBox(height: 12), SelectableText(widget.product.productUrl!, style: txt.bodySmall?.copyWith(color: clr.primary)), ],
            const SizedBox(height: 16),

            // Prijs
            if (_detailPriceString == null && _isLoadingStock) Text("Prijs laden...", style: txt.titleLarge?.copyWith(color: Colors.grey)) else if (_detailPriceString != null) Text('€ $_detailPriceString', style: txt.headlineSmall?.copyWith(color: clr.primary, fontWeight: FontWeight.bold),) else Text('Prijs?', style: txt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),),
            const SizedBox(height: 16),

            // Voorraad
            const Divider(thickness: 0.5),
            Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Text('Voorraad (indicatie)', style: txt.titleLarge?.copyWith(fontSize: 18)),),
            _buildStoreStockSection(context, txt),
            const Divider(height: 32, thickness: 0.5),

            // Details
            _buildDetailsSection(context, txt),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreStockSection(BuildContext context, TextTheme textTheme) {
    if (_isLoadingStock) { return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2.0))); }
    List<Widget> children = [];
    if (_stockError != null) { children.add( Center( child: Padding( padding: const EdgeInsets.only(bottom: 8.0), child: Text( _stockError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), )); }
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
     if (_description == null && _specifications == null && _isLoadingStock) { return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator(), )); }
     else if (_detailsError != null && _description == null && _specifications == null) { return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Text( _detailsError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), ); }
     else { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
           if(_detailsError != null && (_description != null || _specifications != null)) Padding( padding: const EdgeInsets.only(bottom: 15.0), child: Text("Opmerking: $_detailsError", style: TextStyle(color: Colors.orange[800], fontStyle: FontStyle.italic)), ),
           if (_description != null && _description!.isNotEmpty) ...[ Text('Omschrijving', style: textTheme.titleLarge?.copyWith(fontSize: 18)), const SizedBox(height: 8), SelectableText(_description!, style: textTheme.bodyMedium?.copyWith(height: 1.5)), const SizedBox(height: 24), const Divider(thickness: 0.5), const SizedBox(height: 24), ]
           else if (!_isLoadingStock && _detailsError == null) ...[ Text('Omschrijving niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)), const SizedBox(height: 24), ],
           if (_specifications != null && !_specifications!.contains('niet gevonden') && !_specifications!.contains('leeg') && _specifications!.isNotEmpty) ...[ Text('Specificaties', style: textTheme.titleLarge?.copyWith(fontSize: 18)), const SizedBox(height: 8), Container( width: double.infinity, padding: const EdgeInsets.all(12.0), decoration: BoxDecoration( color: clr.surfaceContainerHighest.withAlpha((255*.3).round()), borderRadius: BorderRadius.circular(4.0), ), child: SelectableText( _specifications!, style: textTheme.bodyMedium?.copyWith(height: 1.6, fontFamily: 'monospace'), ) ), ]
           else if (!_isLoadingStock && _detailsError == null) ...[ Text('Specificaties niet gevonden.', style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)), ],
         ], ); }
  }
}