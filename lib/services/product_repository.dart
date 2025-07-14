import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../screens/product_details/core/product_details_data.dart';
import '../screens/product_details/core/product_html_parser.dart';

class DataFetchingException implements Exception {
  final String message;
  final int? statusCode;
  DataFetchingException(this.message, {this.statusCode});

  @override
  String toString() => 'DataFetchingException: $message (Status: $statusCode)';
}

class ProductRepository {
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  static const Map<String, String> _targetStores = {
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

  Future<ProductDetailsScrapeResult> fetchProductDetails(String productUrl) async {
    final response = await http.get(Uri.parse(productUrl), headers: {'User-Agent': _userAgent});

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final isolateArgs = {'htmlBody': responseBody, 'currentProductUrl': productUrl};
      final result = await compute(parseProductDetailsHtmlIsolate, isolateArgs);
      
      if (result.scrapedTitle == null && result.variants.isEmpty && result.priceString == null) {
          throw DataFetchingException('Kon geen bruikbare details uit de productpagina lezen.');
      }
      return result;
    } else {
      throw DataFetchingException('Serverfout bij ophalen details.', statusCode: response.statusCode);
    }
  }

  Future<Map<String, int?>> fetchStoreStocks(String articleCode) async {
    Map<String, int?> finalStocks = {};
    List<String> errors = [];
    String productId;

    try {
      productId = int.parse(articleCode).toString();
    } catch (e) {
      productId = articleCode;
    }

    final gammaEntries = _targetStores.entries.where((e) => e.key.startsWith('Gamma'));
    final karweiEntries = _targetStores.entries.where((e) => e.key.startsWith('Karwei'));

    void parseStockResponse(String responseBody, Iterable<MapEntry<String, String>> entries, String brand) {
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
              finalStocks[storeName] = quantity;
            } else if (quantity is String) {
              finalStocks[storeName] = int.tryParse(quantity);
            } else {
              finalStocks[storeName] = null;
            }
          } else {
            finalStocks[storeName] = null;
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
          parseStockResponse(response.body, gammaEntries, "Gamma");
        } else {
          errors.add('G-${response.statusCode}');
        }
      } catch (e) {
        errors.add('G-Net');
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
          parseStockResponse(response.body, karweiEntries, "Karwei");
        } else {
          errors.add('K-${response.statusCode}');
        }
      } catch (e) {
        errors.add('K-Net');
      }
    }

    if (errors.isNotEmpty) {
      throw DataFetchingException("Fout bij ophalen voorraad: ${errors.join(', ')}");
    }

    return finalStocks;
  }
}