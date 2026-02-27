import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme/app_colors.dart';

/// A single shimmer "block" — use to build skeleton screens
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: AppColors.shimmerHighlight,
          angle: 0.2,
        );
  }
}

/// Full-screen shimmer skeleton for the catalogue list
class CatalogueShimmer extends StatelessWidget {
  const CatalogueShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      itemBuilder: (_, i) => _ShimmerItemCard(delay: i * 60),
    );
  }
}

class _ShimmerItemCard extends StatelessWidget {
  final int delay;
  const _ShimmerItemCard({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          ShimmerBox(width: 48, height: 48, radius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 160, height: 14, radius: 6),
                const SizedBox(height: 8),
                ShimmerBox(width: 80, height: 12, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ShimmerBox(width: 36, height: 36, radius: 18),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, delay: Duration(milliseconds: delay));
  }
}

/// Shimmer for orders/payment history list
class PaymentsShimmer extends StatelessWidget {
  const PaymentsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, i) => _ShimmerPaymentCard(delay: i * 80),
    );
  }
}

class _ShimmerPaymentCard extends StatelessWidget {
  final int delay;
  const _ShimmerPaymentCard({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 120, height: 14, radius: 6),
              ShimmerBox(width: 72, height: 18, radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          ShimmerBox(width: 160, height: 11, radius: 6),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 60, height: 24, radius: 8),
              ShimmerBox(width: 60, height: 24, radius: 8),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, delay: Duration(milliseconds: delay));
  }
}
