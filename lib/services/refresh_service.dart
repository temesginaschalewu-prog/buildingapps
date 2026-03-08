import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/services/snackbar_service.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';

class RefreshService {
  static final RefreshService _instance = RefreshService._internal();
  factory RefreshService() => _instance;
  RefreshService._internal();

  Future<bool> executeRefresh({
    required BuildContext context,
    required Future<void> Function() refreshFunction,
    String successMessage = 'Content updated',
    bool showSuccessMessage = true,
    bool showOfflineMessage = true,
  }) async {
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    if (!connectivityService.isOnline) {
      if (showOfflineMessage && context.mounted) {
        SnackbarService().showOffline(context, action: 'refresh');
      }
      return false;
    }

    try {
      await refreshFunction();

      if (showSuccessMessage && context.mounted) {
        SnackbarService().showSuccess(context, successMessage);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        SnackbarService().showError(
          context,
          'Failed to refresh. Please try again.',
        );
      }
      return false;
    }
  }

  Future<void> pullToRefresh({
    required BuildContext context,
    required Future<void> Function() refreshFunction,
    String successMessage = 'Content updated',
    bool showOfflineMessage = true,
  }) async {
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    if (!connectivityService.isOnline) {
      if (showOfflineMessage && context.mounted) {
        SnackbarService().showError(context, 'Refresh failed');
      }
      throw Exception('Offline');
    }

    try {
      await refreshFunction();
      if (context.mounted) {
        SnackbarService().showSuccess(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarService().showError(
          context,
          'Failed to refresh. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Offline-aware refresh that uses cached data when offline
  Future<T?> refreshWithFallback<T>({
    required BuildContext context,
    required Future<T?> Function() onlineRefresh,
    required T? Function() offlineFallback,
    String? dataType,
  }) async {
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    if (connectivityService.isOnline) {
      try {
        final result = await onlineRefresh();
        if (result != null) return result;
      } catch (e) {
        debugPrint('Online refresh failed, using fallback: $e');
      }
    }

    // Offline or online refresh failed - use fallback
    if (context.mounted && !connectivityService.isOnline) {
      SnackbarService().showOffline(
        context,
        action: dataType != null ? 'load $dataType' : null,
      );
    }

    return offlineFallback();
  }
}
