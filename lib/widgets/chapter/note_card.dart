// lib/widgets/chapter/note_card.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/constants.dart'; // ✅ ADDED MISSING IMPORT
import '../common/app_card.dart';
import '../common/app_button.dart';

/// PRODUCTION-READY NOTE CARD - Based on actual Note model
class NoteCard extends StatelessWidget {
  final Note note;
  final int chapterId;
  final int index;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const NoteCard({
    super.key,
    required this.note,
    required this.chapterId,
    required this.index,
    required this.isDownloaded,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = note.filePath?.toLowerCase().endsWith('.pdf') ?? false;
    final hasFile = note.hasFile;

    return AppCard.solid(
      borderColor: (isPdf ? AppColors.telegramRed : AppColors.telegramBlue)
          .withValues(alpha: 0.14),
      onTap: () => _handleTap(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.06,
                  height: ResponsiveValues.iconSizeXL(context) * 1.06,
                  decoration: BoxDecoration(
                    color: isPdf
                        ? AppColors.telegramRed.withValues(alpha: 0.10)
                        : AppColors.telegramBlue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context),
                    ),
                  ),
                  child: Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.note_alt_rounded,
                    size: ResponsiveValues.iconSizeM(context),
                    color:
                        isPdf ? AppColors.telegramRed : AppColors.telegramBlue,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveValues.spacingS(context)),
                      Wrap(
                        spacing: ResponsiveValues.spacingM(context),
                        runSpacing: ResponsiveValues.spacingXS(context),
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: ResponsiveValues.iconSizeXXS(context),
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(
                                  width: ResponsiveValues.spacingXXS(context)),
                              Text(
                                note.formattedDate,
                                style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          if (hasFile)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveValues.spacingS(context),
                                vertical:
                                    ResponsiveValues.spacingXXS(context),
                              ),
                              decoration: BoxDecoration(
                                color: (isPdf
                                        ? AppColors.telegramRed
                                        : AppColors.telegramBlue)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context),
                                ),
                              ),
                              child: Text(
                                isPdf ? 'PDF' : 'Document',
                                style: AppTextStyles.labelSmall(context).copyWith(
                                  color: isPdf
                                      ? AppColors.telegramRed
                                      : AppColors.telegramBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isDownloading)
                  SizedBox(
                    width: ResponsiveValues.iconSizeXL(context),
                    height: ResponsiveValues.iconSizeXL(context),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: ResponsiveValues.iconSizeS(context) * 1.2,
                          height: ResponsiveValues.iconSizeS(context) * 1.2,
                          child: CircularProgressIndicator(
                            value: downloadProgress,
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.telegramBlue,
                            ),
                          ),
                        ),
                        Text(
                          '${(downloadProgress * 100).toInt()}%',
                          style: AppTextStyles.labelSmall(context).copyWith(
                            fontSize:
                                ResponsiveValues.fontLabelSmall(context) * 0.8,
                            color: AppColors.telegramBlue,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isDownloaded)
                  AppButton.icon(
                    icon: Icons.visibility_rounded,
                    onPressed: onTap,
                  )
                else if (hasFile)
                  AppButton.icon(
                    icon: Icons.download_rounded,
                    onPressed: onDownload,
                  )
                else
                  AppButton.icon(
                    icon: Icons.visibility_rounded,
                    onPressed: onTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 220.ms,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.06,
          end: 0,
          duration: 220.ms,
          delay: (index * 50).ms,
        );
  }

  void _handleTap(BuildContext context) {
    final connectivity = context.read<ConnectivityService>();
    final authProvider = context.read<AuthProvider>();
    final hasReadableOfflineContent = note.content.trim().isNotEmpty;

    if (!authProvider.isAuthenticated) {
      SnackbarService().showError(
          context, AppStrings.pleaseLoginToDownload); // ✅ Using AppStrings
      return;
    }

    // If downloaded, always allow access
    if (isDownloaded) {
      onTap();
      return;
    }

    // If not downloaded and no file, still allow viewing
    if (!note.hasFile) {
      onTap();
      return;
    }

    // If the note body itself is cached, still allow opening offline even when
    // the attached file is not downloaded yet.
    if (hasReadableOfflineContent) {
      onTap();
      return;
    }

    // If has file but no offline-readable content, require connectivity unless
    // the attachment has already been downloaded.
    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'view this note');
      return;
    }

    onTap();
  }
}
