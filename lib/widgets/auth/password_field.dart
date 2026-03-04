import 'package:flutter/material.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../common/responsive_widgets.dart';

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
    if (strength < 0.4) return AppColors.telegramRed;
    if (strength < 0.7) return AppColors.telegramYellow;
    return AppColors.telegramGreen;
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

    return ResponsiveColumn(
      children: [
        ResponsiveText(
          widget.label,
          style: AppTextStyles.labelLarge(context).copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          enabled: widget.enabled,
          validator: _validatePassword,
          onTap: widget.onTap,
          readOnly: widget.readOnly,
          style: AppTextStyles.bodyMedium(context),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                left: ResponsiveValues.spacingM(context),
                right: ResponsiveValues.spacingS(context),
              ),
              child: ResponsiveIcon(
                Icons.lock,
                size: ResponsiveValues.iconSizeS(context),
                color: AppColors.telegramBlue,
              ),
            ),
            suffixIcon: Padding(
              padding: EdgeInsets.only(
                right: ResponsiveValues.spacingS(context),
              ),
              child: IconButton(
                icon: ResponsiveIcon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                  size: ResponsiveValues.iconSizeS(context),
                  color: AppColors.getTextSecondary(context),
                ),
                onPressed: () {
                  setState(() => _obscureText = !_obscureText);
                },
              ),
            ),
            filled: true,
            fillColor: AppColors.getSurface(context),
            contentPadding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
              horizontal: ResponsiveValues.spacingL(context),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
              borderSide: BorderSide(
                color: AppColors.getDivider(context),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
              borderSide: BorderSide(
                color: AppColors.getDivider(context),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
              borderSide: const BorderSide(
                color: AppColors.telegramBlue,
                width: 2.0,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
              borderSide: BorderSide(
                color: AppColors.getDivider(context).withValues(alpha: 0.3),
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
              borderSide: const BorderSide(
                color: AppColors.telegramRed,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
              borderSide: const BorderSide(
                color: AppColors.telegramRed,
                width: 2.0,
              ),
            ),
            errorStyle: AppTextStyles.bodySmall(context).copyWith(
              color: AppColors.telegramRed,
            ),
          ),
        ),
        if (widget.showStrengthIndicator && password.isNotEmpty)
          ResponsiveColumn(
            children: [
              const ResponsiveSizedBox(height: AppSpacing.s),
              ResponsiveRow(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: strength,
                      backgroundColor:
                          AppColors.getSurface(context).withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStrengthColor(strength, context),
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
                      minHeight: ResponsiveValues.progressBarHeight(context),
                    ),
                  ),
                  const ResponsiveSizedBox(width: AppSpacing.m),
                  ResponsiveText(
                    _getStrengthText(strength),
                    style: TextStyle(
                      fontSize: ResponsiveValues.fontLabelSmall(context),
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
