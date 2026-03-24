import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import 'app_bar.dart';
import 'app_brand_logo.dart';
import 'app_empty_state.dart';
import 'app_shimmer.dart';

mixin BaseScreenMixin<T extends StatefulWidget> on State<T> {
  // Core state
  bool _isMounted = false;
  bool _isOffline = false;
  int _pendingCount = 0;
  bool _isRefreshing = false;

  // Stream subscriptions
  StreamSubscription? _connectivitySubscription;

  // Getters for child classes
  bool get isMounted => _isMounted;
  bool get isOffline => _isOffline;
  int get pendingCount => _pendingCount;
  bool get isRefreshing => _isRefreshing;

  // Abstract methods - each screen must implement
  String get screenTitle;
  String? get screenSubtitle;
  Future<void> onRefresh();
  Widget buildContent(BuildContext context);

  // Optional - override if screen has custom app bar needs
  Widget? get appBarLeading => null;
  List<Widget>? get appBarActions => null;
  bool get showThemeToggle => true;
  bool get showNotification => true;

  // Loading state - override per screen
  bool get isLoading => false;
  bool get hasCachedData => false;
  dynamic get errorMessage => null;

  // ✅ Override this in each screen to set the correct shimmer type
  ShimmerType get shimmerType => ShimmerType.textLine;
  int get shimmerItemCount => 5;

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _initialize();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    _updatePendingCount();
  }

  void _setupConnectivityListener() {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!_isMounted) return;

      setState(() {
        _isOffline = !isOnline;
        _updatePendingCount();
      });

      if (isOnline && !_isRefreshing) {
        onRefresh();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!_isMounted) return;

    setState(() {
      _isOffline = !connectivityService.isOnline;
      _updatePendingCount();
    });
  }

  void _updatePendingCount() {
    if (!_isMounted) return;

    try {
      final queueManager = context.read<OfflineQueueManager>();
      _pendingCount = queueManager.pendingCount;
    } catch (e) {
      _pendingCount = 0;
    }
  }

  Future<void> handleRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context, action: 'refresh');
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      await onRefresh();
      setState(() => _isOffline = false);
      _updatePendingCount();
    } catch (e) {
      // Error handled by individual screen
    } finally {
      if (_isMounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ✅ STANDARDIZED loading widget - uses screen's shimmerType
  Widget buildLoadingShimmer() {
    if (shimmerType == ShimmerType.textLine) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppBrandLogo(
                    size: ResponsiveValues.splashLogoSize(context) * 0.68,
                    borderRadius: ResponsiveValues.radiusXLarge(context),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  Text(
                    'Getting everything ready',
                    style: AppTextStyles.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveValues.spacingS(context)),
                  Text(
                    'We are preparing your latest updates so the screen opens in a clean, ready state.',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.telegramBlue,
                      ),
                      backgroundColor:
                          AppColors.getDivider(context).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveValues.screenPadding(context),
      itemCount: shimmerItemCount,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
        child:
            AppShimmer(type: shimmerType, index: index, isOffline: _isOffline),
      ),
    );
  }

  // STANDARDIZED error widget
  Widget buildErrorWidget(String message, {VoidCallback? onRetry}) {
    return Center(
      child: AppEmptyState.error(
        title: 'Error',
        message: message,
        onRetry: onRetry ?? handleRefresh,
        isRefreshing: _isRefreshing,
      ),
    );
  }

  // STANDARDIZED offline widget
  Widget buildOfflineWidget({String? message, String? dataType}) {
    return Center(
      child: AppEmptyState.offline(
        message: message,
        dataType: dataType,
        onRetry: handleRefresh,
        isRefreshing: _isRefreshing,
        pendingCount: _pendingCount,
      ),
    );
  }

  // STANDARDIZED empty data widget
  Widget buildEmptyWidget({
    required String dataType,
    String? customMessage,
    bool isOffline = false,
  }) {
    return Center(
      child: AppEmptyState.noData(
        dataType: dataType,
        customMessage: customMessage,
        onRefresh: handleRefresh,
        isRefreshing: _isRefreshing,
        isOffline: isOffline || _isOffline,
        pendingCount: _pendingCount,
      ),
    );
  }

  // STANDARDIZED app bar
  CustomAppBar buildAppBar() {
    return CustomAppBar(
      title: screenTitle,
      subtitle: _isRefreshing
          ? 'Updating'
          : (_isOffline ? 'Offline' : screenSubtitle),
      leading: appBarLeading,
      actions: appBarActions,
      showThemeToggle: showThemeToggle,
      showNotification: showNotification,
      showOfflineIndicator: _isOffline,
      customTrailing: _isRefreshing
          ? Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.getSurface(context).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // MAIN BUILD METHOD
  Widget buildScreen({
    required Widget content,
    bool showAppBar = true,
    bool showRefreshIndicator = true,
  }) {
    // Error state
    if (errorMessage != null && !hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: showAppBar ? buildAppBar() : null,
        body: buildErrorWidget(errorMessage.toString()),
      );
    }

    // Loading state (no cached data) - ✅ ONLY show shimmer if NO cached data
    if (isLoading && !hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: showAppBar ? buildAppBar() : null,
        body: buildLoadingShimmer(),
      );
    }

    // Offline state (no cached data)
    if (_isOffline && !hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: showAppBar ? buildAppBar() : null,
        body: buildOfflineWidget(),
      );
    }

    // Main content with optional refresh indicator
    final body = showRefreshIndicator
        ? RefreshIndicator(
            onRefresh: handleRefresh,
            color: AppColors.telegramBlue,
            backgroundColor: AppColors.getSurface(context),
            child: content,
          )
        : content;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: showAppBar ? buildAppBar() : null,
      body: body,
    );
  }
}
