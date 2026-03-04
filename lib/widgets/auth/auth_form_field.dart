import 'package:flutter/material.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../common/responsive_widgets.dart';

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
    return ResponsiveColumn(
      children: [
        ResponsiveText(
          label,
          style: AppTextStyles.labelLarge(context).copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.xs),
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
          style: AppTextStyles.bodyMedium(context),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                left: ResponsiveValues.spacingM(context),
                right: ResponsiveValues.spacingS(context),
              ),
              child: ResponsiveIcon(
                prefixIcon,
                size: ResponsiveValues.iconSizeS(context),
                color: AppColors.telegramBlue,
              ),
            ),
            suffixIcon: suffixIcon,
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
    return ResponsiveColumn(
      children: [
        ResponsiveText(
          label,
          style: AppTextStyles.labelLarge(context).copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          validator: validator,
          onTap: onTap,
          style: AppTextStyles.bodyMedium(context),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                left: ResponsiveValues.spacingM(context),
                right: ResponsiveValues.spacingS(context),
              ),
              child: prefixIcon,
            ),
            suffixIcon: suffixIcon,
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
      ],
    );
  }
}
