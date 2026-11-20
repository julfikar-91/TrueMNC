// lib/core/widgets/app_logo.dart
import 'package:flutter/material.dart';

/// TrueMNC brand logo widget with graceful fallback.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 64,
    this.borderRadius = 16,
    this.elevation = 0,
    this.semanticLabel = 'TrueMNC Logo',
  });

  /// Size of the logo (width and height).
  final double size;

  /// Corner radius for clipping.
  final double borderRadius;

  /// Optional shadow elevation.
  final double elevation;

  /// Accessibility semantic label.
  final String semanticLabel;

  /// Default asset path for the app logo.
  static const String assetPath = 'assets/images/logo_app_1.jpeg';

  @override
  Widget build(BuildContext context) {
    Widget logo = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stackTrace) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              Icons.business_center_rounded,
              size: size * 0.55,
              color: colorScheme.primary,
            ),
          );
        },
      ),
    );

    if (elevation > 0) {
      logo = Material(
        elevation: elevation,
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.transparent,
        child: logo,
      );
    }

    return logo;
  }
}
