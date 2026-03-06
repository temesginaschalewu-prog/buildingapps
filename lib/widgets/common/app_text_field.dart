import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextFieldVariant variant;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.variant = TextFieldVariant.glass,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.suffixIcon,
    this.onChanged,
    this.maxLength,
  });

  const AppTextField.password({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.validator,
    this.onChanged,
  })  : prefixIcon = Icons.lock_outline_rounded,
        variant = TextFieldVariant.glass,
        keyboardType = TextInputType.text,
        obscureText = true,
        onTap = null,
        readOnly = false,
        maxLines = 1,
        minLines = null,
        autofocus = false,
        suffixIcon = null,
        maxLength = null;

  const AppTextField.email({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.validator,
    this.onChanged,
  })  : prefixIcon = Icons.email_outlined,
        variant = TextFieldVariant.glass,
        keyboardType = TextInputType.emailAddress,
        obscureText = false,
        onTap = null,
        readOnly = false,
        maxLines = 1,
        minLines = null,
        autofocus = false,
        suffixIcon = null,
        maxLength = null;

  const AppTextField.phone({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.validator,
    this.onChanged,
  })  : prefixIcon = Icons.phone_outlined,
        variant = TextFieldVariant.glass,
        keyboardType = TextInputType.phone,
        obscureText = false,
        onTap = null,
        readOnly = false,
        maxLines = 1,
        minLines = null,
        autofocus = false,
        suffixIcon = null,
        maxLength = null;

  const AppTextField.search({
    super.key,
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.onChanged,
    this.onTap,
  })  : label = '',
        prefixIcon = Icons.search_rounded,
        variant = TextFieldVariant.glass,
        keyboardType = TextInputType.text,
        obscureText = false,
        validator = null,
        readOnly = false,
        maxLines = 1,
        minLines = null,
        autofocus = false,
        suffixIcon = null,
        maxLength = null;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscureText = widget.obscureText;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: AppTextStyles.labelLarge(context).copyWith(
              color: _hasFocus
                  ? AppColors.telegramBlue
                  : AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingXS(context)),
        ],
        _buildTextField(context),
        if (widget.maxLength != null)
          Padding(
            padding: EdgeInsets.only(
              top: ResponsiveValues.spacingXXS(context),
              right: ResponsiveValues.spacingS(context),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.controller.text.length}/${widget.maxLength}',
                style: AppTextStyles.caption(context).copyWith(
                  color: widget.controller.text.length >= widget.maxLength!
                      ? AppColors.telegramRed
                      : AppColors.getTextSecondary(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context) {
    return Container(
      decoration: _getDecoration(context),
      child: TextFormField(
        key: ValueKey(widget.controller.hashCode),
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText && _obscureText,
        enabled: widget.enabled,
        validator: widget.validator,
        onTap: widget.onTap,
        readOnly: widget.readOnly,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        maxLength: widget.maxLength,
        style: AppTextStyles.bodyMedium(context).copyWith(
          color: widget.enabled
              ? AppColors.getTextPrimary(context)
              : AppColors.getTextSecondary(context),
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context).withValues(alpha: 0.5),
          ),
          prefixIcon: _buildPrefixIcon(context),
          suffixIcon: _buildSuffixIcon(context),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingM(context),
          ),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildPrefixIcon(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: ResponsiveValues.spacingM(context),
        right: ResponsiveValues.spacingS(context),
      ),
      child: Icon(
        widget.prefixIcon,
        size: ResponsiveValues.iconSizeS(context),
        color: _hasFocus
            ? AppColors.telegramBlue
            : AppColors.getTextSecondary(context),
      ),
    );
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    if (widget.suffixIcon != null) return widget.suffixIcon;

    if (widget.obscureText) {
      return Padding(
        padding: EdgeInsets.only(right: ResponsiveValues.spacingS(context)),
        child: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            size: ResponsiveValues.iconSizeS(context),
            color: _hasFocus
                ? AppColors.telegramBlue
                : AppColors.getTextSecondary(context),
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      );
    }

    if (widget.controller.text.isNotEmpty && widget.enabled) {
      return Padding(
        padding: EdgeInsets.only(right: ResponsiveValues.spacingS(context)),
        child: IconButton(
          icon: Icon(
            Icons.clear_rounded,
            size: ResponsiveValues.iconSizeS(context),
            color: AppColors.getTextSecondary(context),
          ),
          onPressed: () {
            widget.controller.clear();
            widget.onChanged?.call('');
          },
        ),
      );
    }

    return null;
  }

  BoxDecoration _getDecoration(BuildContext context) {
    final baseDecoration = BoxDecoration(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
    );

    switch (widget.variant) {
      case TextFieldVariant.glass:
        return baseDecoration.copyWith(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.getCard(context).withValues(alpha: 0.4),
              AppColors.getCard(context).withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(
            color: _hasFocus
                ? AppColors.telegramBlue
                : AppColors.getDivider(context).withValues(alpha: 0.2),
            width: _hasFocus ? 2 : 1,
          ),
        );

      case TextFieldVariant.filled:
        return baseDecoration.copyWith(
          color: AppColors.getSurface(context),
          border: Border.all(
            color: _hasFocus ? AppColors.telegramBlue : Colors.transparent,
            width: _hasFocus ? 2 : 0,
          ),
        );

      case TextFieldVariant.outline:
        return baseDecoration.copyWith(
          color: Colors.transparent,
          border: Border.all(
            color: _hasFocus
                ? AppColors.telegramBlue
                : AppColors.getDivider(context),
            width: _hasFocus ? 2 : 1,
          ),
        );
    }
  }
}
