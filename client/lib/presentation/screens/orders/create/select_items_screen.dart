import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../providers/catalogue_provider.dart';
import '../../../providers/cart_provider.dart';
import 'widgets/select_item_card.dart';
import 'widgets/cart_summary_bar.dart';

class SelectItemsScreen extends ConsumerStatefulWidget {
  const SelectItemsScreen({super.key});

  @override
  ConsumerState<SelectItemsScreen> createState() => _SelectItemsScreenState();
}

class _SelectItemsScreenState extends ConsumerState<SelectItemsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure we start with All items.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogueProvider.notifier).setFilter(null);
      // Load items if not already loaded
      ref.read(catalogueProvider.notifier).fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogueState = ref.watch(catalogueProvider);
    final cartState = ref.watch(cartProvider);
    final cartController = ref.read(cartProvider.notifier);

    // Filter Logic
    final allItems = catalogueState.items;
    final query = _searchController.text.toLowerCase();

    var filteredItems = allItems;

    // Apply Search Filter
    if (query.isNotEmpty) {
      filteredItems = filteredItems
          .where((i) => i.name.toLowerCase().contains(query))
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'New Order',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () {
              ref.read(catalogueProvider.notifier).fetchItems();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      autofocus: true,
                      controller: _searchController,
                      onChanged: (val) {
                        // We can also trigger provider search here
                        ref.read(catalogueProvider.notifier).search(val);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: catalogueState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          'No items found',
                          style:
                              GoogleFonts.inter(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final quantity =
                              cartState.items[item.id]?.quantity ?? 0;

                          return SelectItemCard(
                            item: item,
                            quantity: quantity,
                            onAdd: () => cartController.addItem(item),
                            onIncrement: () => cartController.addItem(item),
                            onDecrement: () =>
                                cartController.removeItem(item.id),
                          )
                              .animate()
                              .fadeIn(duration: 200.ms)
                              .slideY(begin: 0.1, end: 0);
                        },
                      ),
          ),

          // Cart Summary
          if (cartState.totalItems > 0)
            CartSummaryBar(
              totalAmount: cartState.totalAmount,
              totalItems: cartState.totalItems,
              onNext: () {
                context.go('/new/review');
              },
            ),
        ],
      ),
    );
  }
}
