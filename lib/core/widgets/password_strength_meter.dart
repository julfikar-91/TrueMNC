// lib/core/widgets/password_strength_meter.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Password strength level.
enum PasswordStrength { empty, weak, medium, strong }

/// Evaluates password strength against TrueMNC policy:
///  - Min 8 characters
///  - At least 1 letter
///  - At least 1 digit
///
/// Strength scale:
///  - weak   : length < 8 OR missing letter OR missing digit
///  - medium : meets minimum policy (8 chars + letter + digit)
///  - strong : medium + length ≥ 12 + special character
PasswordStrength evaluateStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;

  final hasLetter  = RegExp(r'[A-Za-z]').hasMatch(password);
  final hasDigit   = RegExp(r'\d').hasMatch(password);
  final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  final meetsMin   = password.length >= 8 && hasLetter && hasDigit;

  if (!meetsMin) return PasswordStrength.weak;
  if (password.length >= 12 && hasSpecial) return PasswordStrength.strong;
  return PasswordStrength.medium;
}

/// Visual strength bar + label shown below the password field.
///
/// Usage:
/// ```dart
/// PasswordStrengthMeter(password: _passwordController.text)
/// ```
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = evaluateStrength(password);

    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    final (label, color, filledSegments) = switch (strength) {
      PasswordStrength.weak   => ('Weak',   AppColors.strengthWeak,   1),
      PasswordStrength.medium => ('Medium', AppColors.strengthMedium, 2),
      PasswordStrength.strong => ('Strong', AppColors.strengthStrong, 3),
      PasswordStrength.empty  => ('',       Colors.transparent,       0),
    };

    return Semantics(
      label: 'Password strength: $label',
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          _SegmentBar(filledSegments: filledSegments, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.strengthLabel.copyWith(color: color),
          ),
          if (strength == PasswordStrength.weak) ...[
            const SizedBox(height: 2),
            Text(
              _weakHint(password),
              style: AppTextStyles.helperText.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _weakHint(String p) {
    if (p.length < 8)                                   return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(p))               return 'Add at least one letter';
    if (!RegExp(r'\d').hasMatch(p))                     return 'Add at least one digit';
    return 'Password does not meet requirements';
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.filledSegments, required this.color});

  final int filledSegments;
  final Color color;
  static const int _total = 3;

  @override
  Widget build(BuildContext context) {
    final emptyColor = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: List.generate(_total, (i) {
        final filled = i < filledSegments;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: 4,
            margin: EdgeInsets.only(right: i < _total - 1 ? AppSpacing.xs : 0),
            decoration: BoxDecoration(
              color: filled ? color : emptyColor,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
          ),
        );
      }),
    );
  }
}
