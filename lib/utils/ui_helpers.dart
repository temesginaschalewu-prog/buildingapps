import 'package:familyacademyclient/utils/app_enums.dart';
import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../services/connectivity_service.dart';

class UiHelpers {
  static Color getCategoryAccessColor({
    required bool isComingSoon,
    required bool isFree,
    required bool hasActiveSubscription,
    required bool hasPendingPayment,
  }) {
    if (isComingSoon) return AppColors.telegramGray;
    if (isFree || hasActiveSubscription) return AppColors.telegramGreen;
    if (hasPendingPayment) return AppColors.telegramOrange;
    return AppColors.telegramOrange;
  }

  static IconData getCategoryAccessIcon({
    required bool isComingSoon,
    required bool isFree,
    required bool hasActiveSubscription,
    required bool hasPendingPayment,
  }) {
    if (isComingSoon) return Icons.schedule;
    if (isFree || hasActiveSubscription) return Icons.check_circle;
    if (hasPendingPayment) return Icons.pending;
    return Icons.lock;
  }

  static String getCategoryAccessLabel({
    required bool isComingSoon,
    required bool isFree,
    required bool hasActiveSubscription,
    required bool hasPendingPayment,
  }) {
    if (isComingSoon) return 'COMING SOON';
    if (isFree) return 'FREE';
    if (hasActiveSubscription) return 'FULL ACCESS';
    if (hasPendingPayment) return 'PENDING';
    return 'LIMITED';
  }

  static IconData getCourseAccessIcon(
      bool hasFullAccess, bool hasPendingPayment) {
    if (hasFullAccess) return Icons.check_circle;
    if (hasPendingPayment) return Icons.pending;
    return Icons.lock;
  }

  static Color getCourseAccessColor(
      bool hasFullAccess, bool hasPendingPayment) {
    if (hasFullAccess) return AppColors.telegramGreen;
    if (hasPendingPayment) return AppColors.telegramOrange;
    return AppColors.telegramOrange;
  }

  static String getCourseAccessText(
      bool hasFullAccess, bool hasPendingPayment, bool requiresPayment) {
    if (hasFullAccess) return 'Full Access';
    if (hasPendingPayment) return 'Pending Payment';
    if (!requiresPayment) return 'Free';
    return 'Purchase Required';
  }

  static Color getExamStatusColor(
      bool isCompleted, bool passed, bool isInProgress) {
    if (isCompleted) {
      return passed ? AppColors.telegramGreen : AppColors.telegramRed;
    }
    if (isInProgress) return AppColors.telegramBlue;
    return AppColors.telegramGray;
  }

  static Color getExamStatusColorFromString(String status, bool passed) {
    switch (status.toLowerCase()) {
      case 'completed':
        return passed ? AppColors.telegramGreen : AppColors.telegramRed;
      case 'in_progress':
        return AppColors.telegramBlue;
      default:
        return AppColors.telegramGray;
    }
  }

  static String getStreakLevel(int streak) {
    if (streak >= 30) return '🔥 Legendary';
    if (streak >= 20) return '⭐ Superstar';
    if (streak >= 14) return '💪 Committed';
    if (streak >= 7) return '🚀 Consistent';
    if (streak >= 3) return '🌱 Growing';
    if (streak >= 1) return '✨ New';
    return 'Start your streak!';
  }

  static Color getStreakColor(int streak) {
    if (streak >= 100) return const Color(0xFFFFD700);
    if (streak >= 50) return const Color(0xFFC0C0C0);
    if (streak >= 30) return const Color(0xFFCD7F32);
    if (streak >= 14) return AppColors.telegramGreen;
    if (streak >= 7) return AppColors.telegramBlue;
    return AppColors.telegramOrange;
  }

  static String getStreakMessage(int streak) {
    if (streak == 0) return 'Start your learning streak today!';
    if (streak == 1) return 'Great start! Come back tomorrow!';
    if (streak < 7) return '$streak day streak! Keep going!';
    if (streak < 14) return '🌟 $streak day streak! Amazing!';
    if (streak < 30) return '🔥 $streak day streak! You\'re on fire!';
    return '🏆 Legendary $streak day streak!';
  }

  static Color getSubscriptionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.telegramGreen;
      case 'expiring_soon':
        return AppColors.telegramOrange;
      case 'expired':
        return AppColors.telegramRed;
      default:
        return AppColors.telegramBlue;
    }
  }

  static String getSubscriptionStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'expiring_soon':
        return 'EXPIRING SOON';
      case 'expired':
        return 'EXPIRED';
      default:
        return status.toUpperCase();
    }
  }

  static Color getSubscriptionProgressColor(
      double daysRemaining, int totalDays) {
    final ratio = daysRemaining / totalDays;
    if (ratio > 0.5) return AppColors.telegramGreen;
    if (ratio > 0.2) return AppColors.telegramOrange;
    return AppColors.telegramRed;
  }

  static Color getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return AppColors.telegramGreen;
      case 'warning':
        return AppColors.telegramYellow;
      case 'error':
        return AppColors.telegramRed;
      case 'info':
        return AppColors.telegramBlue;
      default:
        return AppColors.telegramPurple;
    }
  }

  static IconData getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'payment_verified':
      case 'payment_rejected':
        return Icons.payment_rounded;
      case 'exam':
      case 'exam_result':
        return Icons.assignment_rounded;
      case 'streak':
      case 'streak_update':
        return Icons.local_fire_department_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'system':
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static Color getOfflineStatusColor(OfflineState state) {
    switch (state) {
      case OfflineState.online:
        return AppColors.telegramGreen;
      case OfflineState.offline:
        return AppColors.warning;
      case OfflineState.queued:
        return AppColors.info;
      case OfflineState.syncing:
        return AppColors.telegramBlue;
    }
  }

  static IconData getOfflineStatusIcon(OfflineState state) {
    switch (state) {
      case OfflineState.online:
        return Icons.wifi_rounded;
      case OfflineState.offline:
        return Icons.wifi_off_rounded;
      case OfflineState.queued:
        return Icons.schedule_rounded;
      case OfflineState.syncing:
        return Icons.sync_rounded;
    }
  }

  static String getOfflineStatusText(OfflineState state, [int? count]) {
    switch (state) {
      case OfflineState.online:
        return 'Online';
      case OfflineState.offline:
        return 'Offline';
      case OfflineState.queued:
        return count != null && count > 0
            ? '$count change${count > 1 ? 's' : ''} pending'
            : 'Changes pending';
      case OfflineState.syncing:
        return 'Syncing...';
    }
  }

  static bool shouldDisableWhenOffline(
    BuildContext context, {
    required bool requiresOnline,
    bool requiresAuth = true,
  }) {
    final connectivity = ConnectivityService();
    if (requiresOnline && connectivity.isOffline) {
      return true;
    }
    return false;
  }

  static Color getDisabledColor(BuildContext context) {
    return AppColors.getTextSecondary(context).withValues(alpha: 0.3);
  }
}
