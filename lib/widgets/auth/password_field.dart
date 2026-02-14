import 'package:flutter/material.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_themes.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool showStrengthIndicator;
  final VoidCallback? onTap;
  final bool readOnly;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.validator,
    this.enabled = true,
    this.showStrengthIndicator = false,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  String? _validatePassword(String? value) {
    if (widget.validator != null) {
      return widget.validator!(value);
    }

    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    return null;
  }

  double _getPasswordStrength(String password) {
    double strength = 0.0;

    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;

    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.1;

    return strength.clamp(0.0, 1.0);
  }

  Color _getStrengthColor(double strength, BuildContext context) {
    if (strength < 0.4) return Theme.of(context).colorScheme.error;
    if (strength < 0.7) return Theme.of(context).colorScheme.secondary;
    return Theme.of(context).colorScheme.tertiary;
  }

  String _getStrengthText(double strength) {
    if (strength < 0.4) return 'Weak';
    if (strength < 0.7) return 'Moderate';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    final password = widget.controller.text;
    final strength = _getPasswordStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: AppThemes.spacingXS),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          enabled: widget.enabled,
          validator: _validatePassword,
          onTap: widget.onTap,
          readOnly: widget.readOnly,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: AppThemes.spacingM,
                right: AppThemes.spacingS,
              ),
              child: Icon(
                Icons.lock,
                size: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: AppThemes.spacingS),
              child: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() => _obscureText = !_obscureText);
                },
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: EdgeInsets.symmetric(
              vertical: ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingM,
                tablet: AppThemes.spacingL,
                desktop: AppThemes.spacingXL,
              ),
              horizontal: AppThemes.spacingL,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2.0,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 2.0,
              ),
            ),
            errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ),
        if (widget.showStrengthIndicator && password.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: AppThemes.spacingS),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: strength,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStrengthColor(strength, context),
                      ),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusSmall),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(width: AppThemes.spacingM),
                  Text(
                    _getStrengthText(strength),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStrengthColor(strength, context),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class ConfirmPasswordField extends StatefulWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String label;
  final String hintText;
  final bool enabled;

  const ConfirmPasswordField({
    super.key,
    required this.passwordController,
    required this.confirmController,
    required this.label,
    required this.hintText,
    this.enabled = true,
  });

  @override
  State<ConfirmPasswordField> createState() => _ConfirmPasswordFieldState();
}

class _ConfirmPasswordFieldState extends State<ConfirmPasswordField> {
  bool _obscureText = true;

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != widget.passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PasswordField(
      controller: widget.confirmController,
      label: widget.label,
      hintText: widget.hintText,
      validator: _validateConfirmPassword,
      enabled: widget.enabled,
    );
  }
}
