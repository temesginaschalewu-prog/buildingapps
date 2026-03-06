import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
import 'app_card.dart';
import 'app_button.dart';

class AppDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    DialogVariant variant = DialogVariant.info,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    Widget? customContent,
    bool barrierDismissible = true,
  }) {
    final colors = _getColors(variant);
    final icon = _getIcon(variant);

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.first.withValues(alpha: 0.2),
                        colors.first.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: colors.first),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Text(
                  title,
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                if (customContent != null)
                  customContent
                else
                  Text(
                    message,
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                    textAlign: TextAlign.center,
                  ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    if (cancelText != null) ...[
                      Expanded(
                        child: AppButton.outline(
                          label: cancelText,
                          onPressed: () {
                            Navigator.of(context).pop(false);
                            onCancel?.call();
                          },
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                    ],
                    Expanded(
                      child: AppButton.primary(
                        label: confirmText ?? 'OK',
                        onPressed: () {
                          Navigator.of(context).pop(true);
                          onConfirm?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> success({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText = 'OK',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      variant: DialogVariant.success,
      confirmText: confirmText,
    );
  }

  static Future<bool?> error({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText = 'OK',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      variant: DialogVariant.error,
      confirmText: confirmText,
    );
  }

  static Future<bool?> warning({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText = 'OK',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      variant: DialogVariant.warning,
      confirmText: confirmText,
    );
  }

  static Future<bool?> info({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText = 'OK',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
    );
  }

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      variant: DialogVariant.confirm,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  static Future<bool?> delete({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.telegramRed,
                      AppColors.telegramPink
                    ]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 32, color: Colors.white),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Text(
                  title,
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Text(
                  message,
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outline(
                        label: cancelText,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: AppButton.danger(
                        label: confirmText,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<String?> input({
    required BuildContext context,
    required String title,
    String? initialValue,
    String hintText = 'Enter value',
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    validator: validator,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context)),
                      ),
                    ),
                    autofocus: true,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outline(
                        label: cancelText,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: AppButton.primary(
                        label: confirmText,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.of(context).pop(controller.text);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    double initialChildSize = 0.9,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return AppCard.glass(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(
                      vertical: ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: child,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void showLoading(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                  ),
                ),
                if (message != null) ...[
                  SizedBox(height: ResponsiveValues.spacingL(context)),
                  Text(
                    message,
                    style: AppTextStyles.bodyMedium(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }

  static Future<void> showToken({
    required BuildContext context,
    required String token,
    required String expiresIn,
  }) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingM(context)),
                      decoration: const BoxDecoration(
                          gradient:
                              LinearGradient(colors: AppColors.blueGradient),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.link_rounded,
                          color: Colors.white, size: 24),
                    ),
                    SizedBox(width: ResponsiveValues.spacingL(context)),
                    Expanded(
                      child: Text(
                        'Link Token',
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Container(
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: SelectableText(
                    token,
                    style: TextStyle(
                      fontSize: ResponsiveValues.fontTitleLarge(context),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: AppColors.telegramBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingM(context),
                    vertical: ResponsiveValues.spacingXS(context),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.telegramYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded,
                          size: ResponsiveValues.iconSizeXS(context),
                          color: AppColors.telegramYellow),
                      SizedBox(width: ResponsiveValues.spacingXS(context)),
                      Text(
                        'Expires in: $expiresIn',
                        style: AppTextStyles.labelSmall(context).copyWith(
                          color: AppColors.telegramYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outline(
                        label: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: AppButton.primary(
                        label: 'Copy',
                        icon: Icons.copy_rounded,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<Color> _getColors(DialogVariant variant) {
    switch (variant) {
      case DialogVariant.success:
        return AppColors.greenGradient;
      case DialogVariant.error:
        return AppColors.pinkGradient;
      case DialogVariant.warning:
        return [AppColors.telegramYellow, AppColors.telegramOrange];
      case DialogVariant.info:
      case DialogVariant.confirm:
      case DialogVariant.input:
        return AppColors.blueGradient;
    }
  }

  static IconData _getIcon(DialogVariant variant) {
    switch (variant) {
      case DialogVariant.success:
        return Icons.check_circle_rounded;
      case DialogVariant.error:
        return Icons.error_outline_rounded;
      case DialogVariant.warning:
        return Icons.warning_rounded;
      case DialogVariant.info:
        return Icons.info_outline_rounded;
      case DialogVariant.confirm:
        return Icons.help_outline_rounded;
      case DialogVariant.input:
        return Icons.edit_rounded;
    }
  }
}
