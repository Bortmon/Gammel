import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/product_repository.dart';
import 'product_details_viewmodel.dart';
import '../scanner_screen.dart'; 
import 'widgets/product_title_header.dart';
import 'widgets/product_image_and_price_card.dart';
import 'widgets/product_info_section.dart';
import 'widgets/product_availability_card.dart';
import 'widgets/product_variant_selector.dart';
import '../../widgets/custom_bottom_nav_bar.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductDetailsViewModel(repository: ProductRepository())
        ..loadDataForProduct(product),
      child: const ProductDetailsView(),
    );
  }
}

class ProductDetailsView extends StatelessWidget {
  const ProductDetailsView({super.key});

  Future<void> _navigateToScannerAndReplace(BuildContext context) async {
    final String? scanResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (!context.mounted) return;
    if (scanResult != null && scanResult.isNotEmpty) {
      Navigator.pop(context, scanResult);
    }
  }

  void _onBottomNavTabSelected(BuildContext context, BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.agenda:
        Navigator.pop(context, 'ACTION_NAVIGATE_TO_AGENDA');
        break;
      case BottomNavTab.home:
        Navigator.popUntil(context, (route) => route.isFirst);
        break;
      case BottomNavTab.scanner:
        _navigateToScannerAndReplace(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProductDetailsViewModel>();
    final clr = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: clr.background,
      appBar: AppBar(
        backgroundColor: clr.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(viewModel.productDetails?.scrapedTitle ?? viewModel.initialProduct?.title ?? "Details", style: txt.titleLarge),
        elevation: 0,
      ),
      body: _buildBody(context, viewModel),
      bottomNavigationBar: CustomBottomNavBar(
        onTabSelected: (tab) => _onBottomNavTabSelected(context, tab),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProductDetailsViewModel viewModel) {
    switch (viewModel.state) {
      case ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              viewModel.errorMessage ?? 'Er is een onbekende fout opgetreden.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        );
      case ViewState.success:
        if (viewModel.productDetails == null) {
          return const Center(child: Text('Geen productdetails gevonden.'));
        }
        final details = viewModel.productDetails!;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                ProductTitleHeader(
                  displayArticleCode: details.scrapedArticleCode ?? viewModel.initialProduct?.articleCode ?? 'Code?',
                  orderStatus: details.status,
                  isLoading: viewModel.state == ViewState.loading,
                ),
                const SizedBox(height: 16),
                ProductImageAndPriceCard(
                  details: details,
                  isLoading: viewModel.state == ViewState.loading,
                  onShowPromotionDetails: () => viewModel.showPromotionDetails(context),
                ),
                if (details.variants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ProductVariantSelector(
                    variants: details.variants,
                    onVariantSelected: (variant) => viewModel.navigateToVariant(context, variant),
                  ),
                ],
                const SizedBox(height: 16),
                ProductAvailabilityCard(
                  isLoadingStock: viewModel.isStockLoading,
                  stockError: viewModel.stockErrorMessage,
                  storeStocks: viewModel.storeStocks,
                  isLoadingDetails: false,
                  deliveryCost: details.deliveryCost,
                  deliveryFreeFrom: details.deliveryFreeFrom,
                  deliveryTime: details.deliveryTime,
                ),
                const SizedBox(height: 16),
                ProductInfoSection(
                  isLoadingDetails: false,
                  description: details.description,
                  specifications: details.specifications,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
    }
  }
}