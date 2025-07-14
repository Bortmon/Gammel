import 'package:flutter/material.dart';
import 'product_stock_list.dart';

class ProductAvailabilityCard extends StatefulWidget {
  final bool isLoadingStock;
  final String? stockError;
  final Map<String, int?> storeStocks;
  
  final bool isLoadingDetails;
  final String? deliveryTime;
  final String? deliveryCost;
  final String? deliveryFreeFrom;

  const ProductAvailabilityCard({
    super.key,
    required this.isLoadingStock,
    this.stockError,
    required this.storeStocks,
    required this.isLoadingDetails,
    this.deliveryTime,
    this.deliveryCost,
    this.deliveryFreeFrom,
  });

  @override
  State<ProductAvailabilityCard> createState() => _ProductAvailabilityCardState();
}

class _ProductAvailabilityCardState extends State<ProductAvailabilityCard> with TickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) {
        setState(() {
          _tabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clr = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: clr.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Beschikbaarheid", style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTabButtons(clr),
          const SizedBox(height: 16),
          IndexedStack(
            index: _tabIndex,
            children: <Widget>[
              ProductStockList(
                isLoadingStock: widget.isLoadingStock,
                stockError: widget.stockError,
                storeStocks: widget.storeStocks,
              ),
              _buildDeliveryInfo(txt, clr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons(ColorScheme clr) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
            label: const Text("Afhalen"),
            onPressed: () => _tabController.animateTo(0),
            style: ElevatedButton.styleFrom(
              foregroundColor: _tabIndex == 0 ? clr.onPrimary : clr.onSurface,
              backgroundColor: _tabIndex == 0 ? clr.primary : clr.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text("Bezorgen"),
            onPressed: () => _tabController.animateTo(1),
            style: ElevatedButton.styleFrom(
              foregroundColor: _tabIndex == 1 ? clr.onPrimary : clr.onSurface,
              backgroundColor: _tabIndex == 1 ? clr.primary : clr.surfaceContainerHighest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryInfo(TextTheme txt, ColorScheme clr) {
    if (widget.isLoadingDetails && widget.deliveryTime == null && widget.deliveryCost == null && widget.deliveryFreeFrom == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.deliveryTime == null && widget.deliveryCost == null && widget.deliveryFreeFrom == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: clr.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Center(child: Text("Bezorginformatie niet beschikbaar.")),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: clr.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: clr.primary, size: 22),
              const SizedBox(width: 10),
              Text("Thuisbezorgd", style: txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (widget.deliveryCost != null && widget.deliveryCost!.isNotEmpty)
                Text(" ${widget.deliveryCost}", style: txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.deliveryTime != null && widget.deliveryTime!.isNotEmpty)
            Text("Verwachte bezorging: ${widget.deliveryTime!}", style: txt.bodyMedium),
          if (widget.deliveryFreeFrom != null && widget.deliveryFreeFrom!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(widget.deliveryFreeFrom!, style: txt.bodySmall?.copyWith(color: clr.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}