import 'package:flutter/material.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_themes.dart';

class AuthFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;

  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.onTap,
    this.suffixIcon,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: AppThemes.spacingXS),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          validator: validator,
          onTap: onTap,
          readOnly: readOnly,
          maxLines: maxLines,
          minLines: minLines,
          autofocus: autofocus,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: AppThemes.spacingM,
                right: AppThemes.spacingS,
              ),
              child: Icon(
                prefixIcon,
                size: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 20,
                  tablet: 22,
                  desktop: 24,
                ),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            suffixIcon: suffixIcon,
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
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
      ],
    );
  }
}

class AuthFormFieldWithIcon extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final Widget prefixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const AuthFormFieldWithIcon({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: AppThemes.spacingXS),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          validator: validator,
          onTap: onTap,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: AppThemes.spacingM,
                right: AppThemes.spacingS,
              ),
              child: prefixIcon,
            ),
            suffixIcon: suffixIcon,
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
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
      ],
    );
  }
}
