// lib/core/widgets/app_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_spacing.dart';

/// Reusable text field with:
/// - Floating label + error display
/// - Obscure-text toggle for password fields
/// - Validator support (works with Form)
/// - 48dp touch target on the toggle icon
/// - Semantic labels for accessibility
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.autofillHints,
    this.initialValue,
    this.semanticLabel,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;

  /// Custom suffix — ignored when [obscureText] is true (toggle takes precedence).
  final Widget? suffixIcon;

  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final String? initialValue;
  final String? semanticLabel;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final showToggle = widget.obscureText;

    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      textField: true,
      child: TextFormField(
        controller: widget.controller,
        initialValue: widget.controller == null ? widget.initialValue : null,
        focusNode: widget.focusNode,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: showToggle ? _obscure : false,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        maxLines: showToggle ? 1 : widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        autofillHints: widget.autofillHints,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon,
          suffixIcon: showToggle ? _buildToggle() : widget.suffixIcon,
          counterText: '',                // hide the maxLength counter
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Semantics(
      button: true,
      label: _obscure ? 'Show password' : 'Hide password',
      child: IconButton(
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        tooltip: _obscure ? 'Show password' : 'Hide password',
        // 48dp touch target enforced by IconButton's default
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
