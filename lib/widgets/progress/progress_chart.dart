import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_text_styles.dart';

class ProgressChart extends StatelessWidget {
  final Map<String, double> weeklyData;
  final Map<String, double> subjectProgress;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const ProgressChart({
    super.key,
    Map<String, double>? weeklyData,
    Map<String, double>? subjectProgress,
    this.isLoading = false,
    this.onRefresh,
  })  : weeklyData = weeklyData ??
            const {
              'Mon': 2.5,
              'Tue': 3.0,
              'Wed': 1.5,
              'Thu': 4.0,
              'Fri': 3.5,
              'Sat': 2.0,
              'Sun': 1.0,
            },
        subjectProgress = subjectProgress ??
            const {
              'Math': 85,
              'Science': 72,
              'English': 90,
              'History': 68,
              'Geography': 78,
            };

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState(context);
    }

    final isDesktop = ScreenSize.isDesktop(context);

    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.lightDivider,
          width: 0.5,
        ),
      ),
      child:
          isDesktop ? _buildDesktopChart(context) : _buildMobileChart(context),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.lightDivider,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusSmall),
            ),
          ),
          SizedBox(height: AppThemes.spacingL),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileChart(BuildContext context) {
    final maxHours = weeklyData.values.reduce((a, b) => a > b ? a : b);
    final totalHours = weeklyData.values.fold(0.0, (sum, hours) => sum + hours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Study Time',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.telegramBlue,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        SizedBox(height: AppThemes.spacingS),
        Text(
          '${totalHours.toStringAsFixed(1)} hours total',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        SizedBox(height: AppThemes.spacingXL),
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxHours + 1,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${weeklyData.values.toList()[groupIndex]}h\n${weeklyData.keys.toList()[groupIndex]}',
                      AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          weeklyData.keys
                              .toList()[value.toInt()]
                              .substring(0, 3),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}h',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      );
                    },
                    reservedSize: 30,
                    interval: 1,
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppColors.getSurface(context),
                    strokeWidth: 0.5,
                  );
                },
              ),
              borderData: FlBorderData(
                show: false,
              ),
              barGroups: weeklyData.entries.map((entry) {
                final index = weeklyData.keys.toList().indexOf(entry.key);
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value,
                      width: ScreenSize.responsiveValue(
                        context: context,
                        mobile: 10,
                        tablet: 12,
                        desktop: 14,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppThemes.borderRadiusSmall),
                        topRight: Radius.circular(AppThemes.borderRadiusSmall),
                      ),
                      color: _getBarColor(entry.value, maxHours),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxHours + 1,
                        color: AppColors.getSurface(context),
                      ),
                    ),
                  ],
                  showingTooltipIndicators: [0],
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: AppThemes.spacingL),
        _buildLegend(context),
      ],
    );
  }

  Widget _buildDesktopChart(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildMobileChart(context),
        ),
        SizedBox(width: AppThemes.spacingXXL),
        Expanded(
          flex: 1,
          child: _buildSubjectProgress(context),
        ),
      ],
    );
  }

  Widget _buildSubjectProgress(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject Progress',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        SizedBox(height: AppThemes.spacingL),
        ...subjectProgress.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppThemes.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      '${entry.value.toInt()}%',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _getProgressColor(entry.value),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusFull),
                  child: LinearProgressIndicator(
                    value: entry.value / 100,
                    backgroundColor: AppColors.getSurface(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(entry.value),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: AppThemes.spacingM,
      runSpacing: AppThemes.spacingS,
      children: [
        _buildLegendItem(AppColors.telegramBlue, 'Study Hours', context),
        _buildLegendItem(AppColors.telegramGreen, 'Target Reached', context),
        _buildLegendItem(
            AppColors.telegramYellow, 'Needs Improvement', context),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Color _getBarColor(double value, double maxValue) {
    final percentage = value / maxValue;
    if (percentage >= 0.7) return AppColors.telegramGreen;
    if (percentage >= 0.4) return AppColors.telegramBlue;
    return AppColors.telegramYellow;
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return AppColors.telegramGreen;
    if (percentage >= 60) return AppColors.telegramBlue;
    return AppColors.telegramYellow;
  }
}
