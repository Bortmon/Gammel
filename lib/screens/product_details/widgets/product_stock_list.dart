import 'package:flutter/material.dart';

class ProductStockList extends StatelessWidget {
  final bool isLoadingStock;
  final String? stockError;
  final Map<String, int?> storeStocks;

  const ProductStockList({
    super.key,
    required this.isLoadingStock,
    this.stockError,
    required this.storeStocks,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingStock) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (stockError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            stockError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (storeStocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            "Voorraad niet beschikbaar.",
            style: TextStyle(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _buildSortedStockList();
  }

  Widget _buildSortedStockList() {
    final sortedEntries = storeStocks.entries.toList()
      ..sort((a, b) {
        bool aIsHaarlem = a.key == 'Gamma Haarlem';
        bool bIsHaarlem = b.key == 'Gamma Haarlem';
        if (aIsHaarlem != bIsHaarlem) return aIsHaarlem ? -1 : 1;
        bool aIsGamma = a.key.startsWith('Gamma');
        bool bIsGamma = b.key.startsWith('Gamma');
        if (aIsGamma != bIsGamma) return aIsGamma ? -1 : 1;
        return a.key.compareTo(b.key);
      });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return _StoreStockCard(
          storeName: entry.key,
          stockCount: entry.value,
        );
      },
    );
  }
}

class _StoreStockCard extends StatelessWidget {
  final String storeName;
  final int? stockCount;

  const _StoreStockCard({
    required this.storeName,
    this.stockCount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isHaarlem = storeName == 'Gamma Haarlem';

    final style = _getStockStyle(stockCount, colorScheme);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: style.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(style.icon, color: style.color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                storeName,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: isHaarlem ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StockBadge(
              text: style.text,
              color: style.color,
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color, String text}) _getStockStyle(
      int? stock, ColorScheme colorScheme) {
    if (stock == null) {
      return (
        icon: Icons.help_outline_rounded,
        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        text: "Onbekend"
      );
    } else if (stock > 5) {
      return (
        icon: Icons.check_circle_rounded,
        color: colorScheme.secondary,
        text: "$stock stuks"
      );
    } else if (stock > 0) {
      return (
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade600,
        text: "$stock stuks"
      );
    } else {
      return (
        icon: Icons.cancel_rounded,
        color: colorScheme.error,
        text: "Uitverkocht"
      );
    }
  }
}

class _StockBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StockBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 85.0), 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center( 
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}