import 'package:flutter/material.dart';

class ProductStockList extends StatelessWidget
{
  final bool isLoadingStock;
  final String? stockError;
  final Map<String, int?> storeStocks;

  const ProductStockList(
  {
    super.key,
    required this.isLoadingStock,
    this.stockError,
    required this.storeStocks,
  });

  @override
  Widget build(BuildContext context)
  {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildStockContent(textTheme, colorScheme, context),
      ),
    );
  }

  List<Widget> _buildStockContent(TextTheme textTheme, ColorScheme colorScheme, BuildContext context)
  {
    if (isLoadingStock)
    {
      return [const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(strokeWidth: 2.5)))];
    }

    List<Widget> children = [];

    if (stockError != null)
    {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            stockError!,
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        )
      );
    }

    if (storeStocks.isEmpty && stockError == null)
    {
      children.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
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
      final sortedEntries = storeStocks.entries.toList()
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
          icon = Icons.help_outline_rounded;
          color = textTheme.bodySmall?.color ?? Colors.grey;
          text = "Niet in assortiment?";
        }
        else if (stockCount > 5)
        {
          icon = Icons.check_circle_outline_rounded;
          color = const Color.fromARGB(255, 0, 209, 10);
          text = "$stockCount stuks";
        }
        else if (stockCount > 0)
        {
          icon = Icons.warning_amber_rounded;
          color = const Color.fromARGB(255, 255, 192, 141);
          text = "$stockCount stuks (laag)";
        }
        else
        {
          icon = Icons.cancel_outlined;
          color = colorScheme.error;
          text = "Niet op voorraad";
        }

        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0), 
            child: Row(
              children:
              [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 5), 
                Expanded(
                  child: Text(
                    storeName,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: isHaarlem ? FontWeight.bold : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  )
                ),
                Text(text, style: textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        );
      }
    }
    return children;
  }
}