import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'product_details_data.dart';

// Helper functie om een string naar Title Case te converteren
String _toTitleCase(String text) {
  if (text.isEmpty) return '';
  return text.split(' ')
      .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
      .join(' ');
}


Future<ProductDetailsScrapeResult> parseProductDetailsHtmlIsolate(Map<String, String> args) async {
  final String htmlBody = args['htmlBody']!;
  final String currentProductUrl = args['currentProductUrl']!;

  final document = parse(htmlBody);
  List<ProductVariant> foundVariants = [];
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
  String? scrapedPageTitle;
  String? scrapedPageArticleCode;
  String? scrapedPageEan;

  final RegExp priceCleanRegex = RegExp(r'[^\d,.]');
  final RegExp promoDescCleanupRegex1 = RegExp(r'Bekijk alle producten.*$', multiLine: true);
  final RegExp promoDescCleanupRegex2 = RegExp(r'\s+');

  try {
    final Uri uri = Uri.parse(currentProductUrl);
    if (uri.pathSegments.isNotEmpty) {
      final int pIndex = uri.pathSegments.lastIndexOf('p');
      if (pIndex != -1 && pIndex + 1 < uri.pathSegments.length) {
        String idSegment = uri.pathSegments[pIndex + 1];
        if (idSegment.startsWith('B') || idSegment.startsWith('b')) {
          idSegment = idSegment.substring(1);
        }
        final int? parsedId = int.tryParse(idSegment);
        if (parsedId != null) {
            scrapedPageArticleCode = parsedId.toString();
        } else {
            scrapedPageArticleCode = idSegment;
        }
      }
      // Probeer titel uit URL slug te halen als fallback of primaire bron
      if (pIndex > 0 && pIndex -1 < uri.pathSegments.length) {
        String slug = uri.pathSegments[pIndex -1];
        if (slug.isNotEmpty && slug != "assortiment") { // Voorkom dat "assortiment" de titel wordt
            scrapedPageTitle = _toTitleCase(slug.replaceAll('-', ' '));
        }
      }
    }

    if (scrapedPageArticleCode == null || scrapedPageArticleCode.isEmpty) {
        dom.Element? articleElement = document.querySelector('.product-sku .value, .product-info__sku, [data-product-id], [itemprop="sku"]');
        if (articleElement != null) {
            scrapedPageArticleCode = articleElement.text.trim();
            if (scrapedPageArticleCode.isEmpty && articleElement.attributes.containsKey('data-product-id')) {
                scrapedPageArticleCode = articleElement.attributes['data-product-id']?.trim();
            } else if (scrapedPageArticleCode.isEmpty && articleElement.attributes.containsKey('content')) {
                scrapedPageArticleCode = articleElement.attributes['content']?.trim();
            }
        }
        if (scrapedPageArticleCode != null && scrapedPageArticleCode.toLowerCase().startsWith('art.')) {
            scrapedPageArticleCode = scrapedPageArticleCode.substring(4).trim();
        }
        if (scrapedPageArticleCode != null && scrapedPageArticleCode.toLowerCase().startsWith('artikelnummer:')) {
            scrapedPageArticleCode = scrapedPageArticleCode.substring(14).trim();
        }
    }

    // Als titel nog niet uit URL is gehaald, probeer HTML te parsen
    if (scrapedPageTitle == null || scrapedPageTitle.isEmpty) {
        scrapedPageTitle = document.querySelector('h1.pdp-title, .product-title h1, .page-title')?.text.trim();
        if (scrapedPageTitle == null || scrapedPageTitle.isEmpty) {
            scrapedPageTitle = document.querySelector('title')?.text.split('|').first.trim();
            if (scrapedPageTitle != null && scrapedPageTitle.contains(" - GAMMA")) {
                scrapedPageTitle = scrapedPageTitle.substring(0, scrapedPageTitle.indexOf(" - GAMMA")).trim();
            }
             if (scrapedPageTitle != null && scrapedPageTitle.contains(" | GAMMA")) { // Nog een variant
                scrapedPageTitle = scrapedPageTitle.substring(0, scrapedPageTitle.indexOf(" | GAMMA")).trim();
            }
        }
    }
    
    dom.Element? eanElement = document.querySelector('[itemprop="gtin13"], [itemprop="gtin"], .product-ean .value');
    if (eanElement != null) {
        scrapedPageEan = eanElement.attributes['content'] ?? eanElement.text.trim();
    }
    if (scrapedPageEan != null && scrapedPageEan.isEmpty) {
        scrapedPageEan = null;
    }

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
        if (alt != null && !alt.contains('/placeholders/'))
        {
            tmp = alt;
        }
        else
        {
            tmp = null;
        }
      }
      if (tmp != null && tmp.startsWith('http'))
      {
          fImgUrl = tmp;
      }
    }
    if (fImgUrl == null)
    {
      final metaImg = document.querySelector('meta[itemprop="image"]');
      String? mUrl = metaImg?.attributes['content'];
      if (mUrl != null && mUrl.startsWith('http'))
      {
          fImgUrl = mUrl;
      }
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
        if (intP.isNotEmpty && decP.isNotEmpty)
        {
            newPrice = '$intP.$decP';
        }
      }
    }

    newOldPrice = document.querySelector('.product-price-base .before-price')?.text.trim() ??
                  document.querySelector('.pdp-price__retail .price-amount')?.text.trim() ??
                  document.querySelector('.price-suggested .price-amount')?.text.trim() ??
                  document.querySelector('span[data-price-type="oldPrice"] .price')?.text.trim();
    if (newOldPrice != null)
    {
      newOldPrice = newOldPrice.replaceAll(priceCleanRegex, '').replaceFirst(',', '.');
      if (newOldPrice.isEmpty || newOldPrice == newPrice)
      {
          newOldPrice = null;
      }
    }

    newPriceUnit = document.querySelector('.pdp-price__unit')?.text.trim() ??
                   document.querySelector('.product-tile-price-unit')?.text.trim();
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
      newDiscount = document.querySelector('.product-labels .label-item')?.text.trim() ??
                    document.querySelector('.sticker-action')?.text.trim() ??
                    document.querySelector('.product-badge .badge-text')?.text.trim();
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

    final List<dom.Element> variantGroups = document.querySelectorAll('div.variant.js-product-variant');
    for (dom.Element groupElement in variantGroups) {
      final strongElement = groupElement.querySelector('label strong.js-variant-name');
      String groupName = strongElement?.text.trim().replaceAll(':', '') ?? 'Variant';

      final List<dom.Element> variantTiles = groupElement.querySelectorAll('a.variant-tile');
      if (variantTiles.isNotEmpty) {
        for (dom.Element tile in variantTiles) {
          String variantName = tile.text.trim();
          String? productUrlFromTile = tile.attributes['href'];
          bool isSelected = tile.classes.contains('selected') || productUrlFromTile == null || productUrlFromTile.isEmpty;
          
          if (productUrlFromTile == null || productUrlFromTile.isEmpty) {
              if (isSelected) {
                  productUrlFromTile = currentProductUrl;
              } else {
                  continue; 
              }
          }

          if (!productUrlFromTile.startsWith('http')) {
            productUrlFromTile = 'https://www.gamma.nl$productUrlFromTile';
          }

          if (variantName.isNotEmpty) {
            foundVariants.add(ProductVariant(
              groupName: groupName,
              variantName: variantName,
              productUrl: productUrlFromTile,
              isSelected: isSelected,
            ));
          }
        }
      } else {
        final dom.Element? selectElement = groupElement.querySelector('select.js-base-product-select');
        if (selectElement != null) {
          final List<dom.Element> options = selectElement.querySelectorAll('option.base-product-option');
          for (dom.Element option in options) {
            String variantName = option.text.trim();
            String? productUrlFromOption = option.attributes['data-link'];
            bool isSelected = option.attributes.containsKey('selected');

            if (productUrlFromOption != null && productUrlFromOption.isNotEmpty) {
               if (!productUrlFromOption.startsWith('http')) {
                productUrlFromOption = 'https://www.gamma.nl$productUrlFromOption';
              }
              if (variantName.isNotEmpty) {
                foundVariants.add(ProductVariant(
                  groupName: groupName,
                  variantName: variantName,
                  productUrl: productUrlFromOption,
                  isSelected: isSelected,
                ));
              }
            }
          }
        }
      }
    }
  } catch (e,s) {
    // no-op
  }

  return ProductDetailsScrapeResult(
    scrapedTitle: scrapedPageTitle,
    scrapedArticleCode: scrapedPageArticleCode,
    scrapedEan: scrapedPageEan,
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
    promotionDescription: newPromoDesc,
    variants: foundVariants,
  );
}