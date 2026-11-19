// lib/core/widgets/skeleton_list.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Skeleton loading list placeholder with shimmering effect.
class SkeletonList extends StatefulWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
    final highlightColor =
        isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlight;

    return Semantics(
      label: 'Loading content skeleton placeholder',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return ListView.separated(
            padding: widget.padding,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return _SkeletonCard(
                baseColor: baseColor,
                highlightColor: highlightColor,
                animationValue: _controller.value,
              );
            },
          );
        },
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.baseColor,
    required this.highlightColor,
    required this.animationValue,
  });

  final Color baseColor;
  final Color highlightColor;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo placeholder
          _shimmerBlock(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          const SizedBox(width: AppSpacing.md),
          // Details placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBlock(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                const SizedBox(height: AppSpacing.sm),
                _shimmerBlock(
                  width: 140,
                  height: 12,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _shimmerBlock(
                      width: 60,
                      height: 20,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _shimmerBlock(
                      width: 80,
                      height: 20,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBlock({
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment(-1.0 + (animationValue * 2.0), -0.3),
          end: Alignment(1.0 + (animationValue * 2.0), 0.3),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
