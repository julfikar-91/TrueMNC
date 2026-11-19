// lib/core/widgets/app_button.dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Button variant.
enum AppButtonVariant { primary, secondary, text }

/// Reusable button with loading state, 48dp touch target, and semantic label.
///
/// Usage:
/// ```dart
/// AppButton(label: 'Sign In', onPressed: _signIn, isLoading: state.isLoading)
/// AppButton.secondary(label: 'Cancel', onPressed: _cancel)
/// AppButton.text(label: 'Skip', onPressed: _skip)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.semanticLabel,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.semanticLabel,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = false,
    this.semanticLabel,
  }) : variant = AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final AppButtonVariant variant;

  /// Whether the button should stretch to full width.
  final bool expand;

  /// Overrides the accessibility label (defaults to [label]).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild(context);

    Widget button = switch (variant) {
      AppButtonVariant.primary => icon != null
          ? FilledButton.icon(
              onPressed: effectiveOnPressed,
              icon: icon!,
              label: child,
            )
          : FilledButton(
              onPressed: effectiveOnPressed,
              child: child,
            ),
      AppButtonVariant.secondary => icon != null
          ? OutlinedButton.icon(
              onPressed: effectiveOnPressed,
              icon: icon!,
              label: child,
            )
          : OutlinedButton(
              onPressed: effectiveOnPressed,
              child: child,
            ),
      AppButtonVariant.text => icon != null
          ? TextButton.icon(
              onPressed: effectiveOnPressed,
              icon: icon!,
              label: child,
            )
          : TextButton(
              onPressed: effectiveOnPressed,
              child: child,
            ),
    };

    // Enforce minimum 48dp height via SizedBox
    button = SizedBox(
      height: AppSpacing.minTouchTarget,
      child: expand
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: !isLoading && onPressed != null,
      child: button,
    );
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: variant == AppButtonVariant.primary
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return Text(label);
  }
}
