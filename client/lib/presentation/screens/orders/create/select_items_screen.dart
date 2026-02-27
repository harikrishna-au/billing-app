import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../providers/catalogue_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../widgets/shimmer_loader.dart';
import 'widgets/select_item_card.dart';
import 'widgets/cart_summary_bar.dart';

class SelectItemsScreen extends ConsumerStatefulWidget {
  const SelectItemsScreen({super.key});

  @override
  ConsumerState<SelectItemsScreen> createState() => _SelectItemsScreenState();
}

class _SelectItemsScreenState extends ConsumerState<SelectItemsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogueProvider.notifier).setFilter(null);
      ref.read(catalogueProvider.notifier).fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogueState = ref.watch(catalogueProvider);
    final cartState = ref.watch(cartProvider);
    final cartController = ref.read(cartProvider.notifier);

    final filteredItems = catalogueState.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'New Order',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            color: AppColors.textSecondary,
            onPressed: () =>
                ref.read(catalogueProvider.notifier).fetchItems(),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (val) {
                  ref.read(catalogueProvider.notifier).search(val);
                  setState(() {});
                },
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search products & services...',
                  hintStyle: GoogleFonts.dmSans(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.textLight, size: 20),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            ref.read(catalogueProvider.notifier).search('');
                            setState(() {});
                          },
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textLight, size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  filled: false,
                ),
              ),
            ),
          ),

          // Items list
          Expanded(
            child: catalogueState.isLoading
                ? const CatalogueShimmer()
                : catalogueState.error != null
                    ? _ErrorState(
                        onRetry: () =>
                            ref.read(catalogueProvider.notifier).fetchItems(),
                      )
                    : filteredItems.isEmpty
                        ? _EmptyState(
                            hasQuery: _searchController.text.isNotEmpty)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final qty =
                                  cartState.items[item.id]?.quantity ?? 0;

                              return SelectItemCard(
                                item: item,
                                quantity: qty,
                                onAdd: () => cartController.addItem(item),
                                onIncrement: () =>
                                    cartController.addItem(item),
                                onDecrement: () =>
                                    cartController.removeItem(item.id),
                              );
                            },
                          ),
          ),

          // Cart bar
          if (cartState.totalItems > 0)
            CartSummaryBar(
              totalAmount: cartState.totalAmount,
              totalItems: cartState.totalItems,
              onNext: () => context.go('/new/review'),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 30, color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No items match your search' : 'No items in catalogue',
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (hasQuery)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Try a different keyword',
                style: GoogleFonts.dmSans(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.cloud_off_rounded,
                size: 30, color: AppColors.error.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load items',
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Try again',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
