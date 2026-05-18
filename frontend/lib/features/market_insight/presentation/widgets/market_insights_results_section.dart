import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../data/models/market_insights_models.dart';

class MarketInsightsResultsSection extends StatelessWidget {
  final MarketInsightsData data;
  final int animationSeed;
  final VoidCallback onChangeRole;
  final VoidCallback onRefresh;

  const MarketInsightsResultsSection({
    super.key,
    required this.data,
    required this.animationSeed,
    required this.onChangeRole,
    required this.onRefresh,
  });

  bool get _hasExperienceData =>
      data.experienceShares.any((item) => item.value > 0);

  bool get _hasSalaryData =>
      data.salaryInsights.maxMonthlySalary > 0 ||
      data.salaryInsights.avgMonthlySalary > 0 ||
      data.salaryInsights.minMonthlySalary > 0;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            _ResultsHeader(
              title: '${data.jobTitle} — Market Insights',
              subtitle:
                  'Live backend crawler result based on the selected market track',
              onChangeRole: onChangeRole,
              onRefresh: onRefresh,
            ),
            SizedBox(height: context.h(16)),
            _AnimatedEntry(
              delay: 0,
              child: _ResultsOverview(
                data: data,
                animationSeed: animationSeed,
                hasSalaryData: _hasSalaryData,
              ),
            ),
            SizedBox(height: context.h(16)),
            _AnimatedEntry(
              delay: 80,
              child: _BackendResultCard(
                jobTitle: data.jobTitle,
                jobOpenings: data.jobOpenings,
              ),
            ),
            SizedBox(height: context.h(16)),
            _AnimatedEntry(
              delay: 140,
              child: _hasExperienceData
                  ? _ExperienceCard(
                      data: data,
                      animationSeed: animationSeed,
                    )
                  : const _UnavailableCard(
                      title: 'Demand by Experience Level',
                      message:
                          'Experience distribution is not available for this track yet.',
                    ),
            ),
            SizedBox(height: context.h(16)),
            _AnimatedEntry(
              delay: 200,
              child: data.topSkills.isNotEmpty
                  ? _SkillsCard(
                      skills: data.topSkills,
                      animationSeed: animationSeed,
                    )
                  : const _UnavailableCard(
                      title: 'Top Required Job Skills',
                      message:
                          'Skills breakdown is not available for this track yet.',
                    ),
            ),
            SizedBox(height: context.h(16)),
            _AnimatedEntry(
              delay: 260,
              child: data.yearlyDemand.isNotEmpty
                  ? _DemandOverYearCard(
                      points: data.yearlyDemand,
                      animationSeed: animationSeed,
                    )
                  : const _UnavailableCard(
                      title: 'Demand Over the Year',
                      message:
                          'Monthly demand points are not available for this track yet.',
                    ),
            ),
            SizedBox(height: context.h(16)),
            _AnimatedEntry(
              delay: 320,
              child: data.topGovernorates.isNotEmpty
                  ? _GovernoratesCard(
                      governorates: data.topGovernorates,
                      animationSeed: animationSeed,
                    )
                  : const _UnavailableCard(
                      title: 'Top 5 Hiring Governorates',
                      message:
                          'Governorate distribution is not available for this track yet.',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AnimatedEntry({
    required this.child,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onChangeRole;
  final VoidCallback onRefresh;

  const _ResultsHeader({
    required this.title,
    required this.subtitle,
    required this.onChangeRole,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.responsiveText(
              textTheme.title1Bold.copyWith(
                color: isDark ? AppColors.grey100 : AppColors.blue900,
                fontSize: 19,
                height: 1.18,
              ),
            ),
          ),
          SizedBox(height: context.h(12)),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.responsiveText(
              textTheme.title2Medium.copyWith(
                color: isDark ? AppColors.blue200 : AppColors.grey800,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: context.h(16)),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  filled: false,
                  icon: Icons.edit_outlined,
                  text: 'Change Role',
                  onTap: onChangeRole,
                ),
              ),
              SizedBox(width: context.w(12)),
              Expanded(
                child: _ActionButton(
                  filled: true,
                  icon: Icons.refresh_rounded,
                  text: 'Refresh',
                  onTap: onRefresh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool filled;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ActionButton({
    required this.filled,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = filled
        ? (isDark ? AppColors.lightBlue500 : AppColors.lightBlue700)
        : (isDark ? AppColors.blue700 : AppColors.grey100);

    final textColor = filled
        ? (isDark ? AppColors.blue700 : AppColors.grey50)
        : (isDark ? AppColors.grey100 : AppColors.lightBlue700);

    final borderColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.r(50)),
      child: Container(
        constraints: BoxConstraints(
          minHeight: context.h(40),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.w(12),
          vertical: context.h(9),
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(context.r(50)),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: context.icon(16), color: textColor),
            SizedBox(width: context.w(7)),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendResultCard extends StatelessWidget {
  final String jobTitle;
  final int jobOpenings;

  const _BackendResultCard({
    required this.jobTitle,
    required this.jobOpenings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(16),
      ),
      decoration: _cardDecoration(context, isDark),
      child: Row(
        children: [
          Container(
            width: context.w(48),
            height: context.w(48),
            decoration: BoxDecoration(
              color: AppColors.lightBlue100,
              borderRadius: BorderRadius.circular(context.r(14)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.lightBlue700,
              size: context.icon(29),
            ),
          ),
          SizedBox(width: context.w(13)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend crawler completed',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.grey100 : AppColors.blue900,
                    fontFamily: 'Inter',
                    fontSize: context.sp(15.5),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: context.h(5)),
                Text(
                  '${_formatNumber(jobOpenings)} jobs found for $jobTitle.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.blue200 : AppColors.grey800,
                    fontFamily: 'Inter',
                    fontSize: context.sp(12.5),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsOverview extends StatelessWidget {
  final MarketInsightsData data;
  final int animationSeed;
  final bool hasSalaryData;

  const _ResultsOverview({
    required this.data,
    required this.animationSeed,
    required this.hasSalaryData,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        final metricCards = [
          _MiniMetricCard(
            iconPath: 'assets/images/market_insights/job_open.png',
            title: 'Job Openings',
            value: _AnimatedNumberText(
              value: data.jobOpenings.toDouble(),
              animationSeed: animationSeed,
              formatCommas: true,
              style: _valueStyle(context),
            ),
          ),
          _MiniMetricCard(
            iconPath: 'assets/images/market_insights/market_growth.png',
            title: 'Market Growth',
            value: Text(
              data.marketGrowthPercent > 0
                  ? '+${data.marketGrowthPercent}%'
                  : 'N/A',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _valueStyle(context),
            ),
          ),
          _MiniMetricCard(
            iconPath: 'assets/images/market_insights/avg_exp.png',
            title: 'Avg. Experience',
            value: Text(
              data.avgExperienceYears > 0
                  ? '${data.avgExperienceYears.toStringAsFixed(1)} Years'
                  : 'N/A',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _valueStyle(context),
            ),
          ),
        ];

        if (isCompact) {
          return Column(
            children: [
              for (int i = 0; i < metricCards.length; i++) ...[
                metricCards[i],
                SizedBox(height: context.h(12)),
              ],
              _SalaryInsightsCard(
                data: data.salaryInsights,
                animationSeed: animationSeed,
                hasData: hasSalaryData,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 92,
              child: Column(
                children: [
                  metricCards[0],
                  SizedBox(height: context.h(12)),
                  metricCards[1],
                  SizedBox(height: context.h(12)),
                  metricCards[2],
                ],
              ),
            ),
            SizedBox(width: context.w(12)),
            Expanded(
              flex: 108,
              child: _SalaryInsightsCard(
                data: data.salaryInsights,
                animationSeed: animationSeed,
                hasData: hasSalaryData,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final Widget value;

  const _MiniMetricCard({
    required this.iconPath,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: context.h(78),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.w(12),
        vertical: context.h(12),
      ),
      decoration: _cardDecoration(context, isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IconTile(iconPath: iconPath),
          SizedBox(width: context.w(12)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.grey100 : AppColors.blue900,
                    fontFamily: 'Inter',
                    fontSize: context.sp(13.5),
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: context.h(6)),
                DefaultTextStyle.merge(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryInsightsCard extends StatelessWidget {
  final SalaryInsights data;
  final int animationSeed;
  final bool hasData;

  const _SalaryInsightsCard({
    required this.data,
    required this.animationSeed,
    required this.hasData,
  });

  Widget _salaryValue(BuildContext context, int value) {
    if (!hasData || value <= 0) {
      return Text(
        'N/A',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _valueStyle(context),
      );
    }

    return _AnimatedNumberText(
      value: value.toDouble(),
      animationSeed: animationSeed,
      prefix: '\$',
      suffix: ' / month',
      formatCommas: true,
      style: _valueStyle(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: context.h(222),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.w(14),
        vertical: context.h(15),
      ),
      decoration: _cardDecoration(context, isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SalaryTitleRow(),
          SizedBox(height: context.h(14)),
          _SalaryRow(
            iconPath: 'assets/images/market_insights/max_salary.png',
            label: 'Maximum Salary',
            value: _salaryValue(context, data.maxMonthlySalary),
          ),
          SizedBox(height: context.h(12)),
          _SalaryRow(
            iconPath: 'assets/images/market_insights/avg_salary.png',
            label: 'Average Salary',
            value: _salaryValue(context, data.avgMonthlySalary),
          ),
          SizedBox(height: context.h(12)),
          _SalaryRow(
            iconPath: 'assets/images/market_insights/min_salary.png',
            label: 'Minimum Salary',
            value: _salaryValue(context, data.minMonthlySalary),
          ),
        ],
      ),
    );
  }
}

class _SalaryTitleRow extends StatelessWidget {
  const _SalaryTitleRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        const _IconTile(
          iconPath: 'assets/images/market_insights/salary_insights.png',
          large: true,
        ),
        SizedBox(width: context.w(10)),
        Expanded(
          child: Text(
            'Salary Insights',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? AppColors.grey100 : AppColors.blue900,
              fontFamily: 'Inter',
              fontSize: context.sp(16.5),
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _SalaryRow extends StatelessWidget {
  final String iconPath;
  final String label;
  final Widget value;

  const _SalaryRow({
    required this.iconPath,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _IconTile(iconPath: iconPath),
        SizedBox(width: context.w(10)),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.grey100 : AppColors.blue900,
                  fontFamily: 'Inter',
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              SizedBox(height: context.h(4)),
              DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final String iconPath;
  final bool large;

  const _IconTile({
    required this.iconPath,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final tileSize = large ? context.w(46) : context.w(42);
    final iconSize = large ? context.icon(27) : context.icon(24);

    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: AppColors.lightBlue100,
        borderRadius: BorderRadius.circular(context.r(12)),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        iconPath,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  final MarketInsightsData data;
  final int animationSeed;

  const _ExperienceCard({
    required this.data,
    required this.animationSeed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const entryColor = Color(0xFF437BD6);
    const intermediateColor = Color(0xFFC560C5);
    const seniorColor = Color(0xFF35B7D7);
    const expertColor = Color(0xFF9C8ECB);

    double getValue(String label) {
      return data.experienceShares
          .where((e) => e.label == label)
          .map((e) => e.value)
          .fold<double>(0, (previous, current) => current);
    }

    final chartData = [
      _ChartSlice(label: 'Entry', value: getValue('Entry'), color: entryColor),
      _ChartSlice(
        label: 'Intermediate',
        value: getValue('Intermediate'),
        color: intermediateColor,
      ),
      _ChartSlice(
        label: 'Senior',
        value: getValue('Senior'),
        color: seniorColor,
      ),
      _ChartSlice(
        label: 'Expert',
        value: getValue('Expert'),
        color: expertColor,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: _cardDecoration(context, isDark),
      child: Column(
        children: [
          _SectionTitle('Demand by Experience Level'),
          SizedBox(height: context.h(24)),
          _InteractiveDonutChart(
            slices: chartData,
            animationSeed: animationSeed,
          ),
          SizedBox(height: context.h(24)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: context.w(12),
            runSpacing: context.h(10),
            children: chartData
                .map(
                  (slice) => _LegendItem(
                    color: slice.color,
                    label: slice.label,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  final List<SkillDemand> skills;
  final int animationSeed;

  const _SkillsCard({
    required this.skills,
    required this.animationSeed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: _cardDecoration(context, isDark),
      child: Column(
        children: [
          const _SectionTitle('Top Required Job Skills'),
          SizedBox(height: context.h(16)),
          ...skills.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final skill = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == skills.length - 1 ? 0 : context.h(12),
                ),
                child: _ProgressMetricRow(
                  label: skill.skill,
                  valueText: '${skill.percentage}%',
                  progress: skill.percentage / 100,
                  animationSeed: animationSeed,
                  animationDelay: index * 90,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DemandOverYearCard extends StatelessWidget {
  final List<MonthlyDemandPoint> points;
  final int animationSeed;

  const _DemandOverYearCard({
    required this.points,
    required this.animationSeed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: _cardDecoration(context, isDark),
      child: Column(
        children: [
          const _SectionTitle('Demand Over the Year'),
          SizedBox(height: context.h(16)),
          _InteractiveAreaChart(
            points: points,
            animationSeed: animationSeed,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _GovernoratesCard extends StatelessWidget {
  final List<GovernorateHiring> governorates;
  final int animationSeed;

  const _GovernoratesCard({
    required this.governorates,
    required this.animationSeed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = governorates.isEmpty
        ? 1
        : governorates.map((e) => e.jobs).reduce(math.max).toDouble();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: _cardDecoration(context, isDark),
      child: Column(
        children: [
          const _SectionTitle('Top 5 Hiring Governorates'),
          SizedBox(height: context.h(16)),
          ...governorates.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final governorate = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == governorates.length - 1 ? 0 : context.h(12),
                ),
                child: _ProgressMetricRow(
                  label: governorate.governorate,
                  valueText: '${_formatNumber(governorate.jobs)} jobs',
                  progress: governorate.jobs / maxValue,
                  animationSeed: animationSeed,
                  animationDelay: index * 90,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isDark ? AppColors.grey100 : AppColors.blue900,
        fontFamily: 'Inter',
        fontSize: context.sp(19),
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  final String title;
  final String message;

  const _UnavailableCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: _cardDecoration(context, isDark),
      child: Column(
        children: [
          _SectionTitle(title),
          SizedBox(height: context.h(12)),
          Icon(
            Icons.insights_outlined,
            color: isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
            size: context.icon(34),
          ),
          SizedBox(height: context.h(10)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.blue200 : AppColors.grey800,
              fontFamily: 'Inter',
              fontSize: context.sp(13),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveDonutChart extends StatefulWidget {
  final List<_ChartSlice> slices;
  final int animationSeed;

  const _InteractiveDonutChart({
    required this.slices,
    required this.animationSeed,
  });

  @override
  State<_InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<_InteractiveDonutChart> {
  int? selectedIndex;
  static const double sizeValue = 150;
  static const double strokeWidth = 32;

  @override
  void didUpdateWidget(covariant _InteractiveDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationSeed != widget.animationSeed) {
      selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: sizeValue,
      height: sizeValue,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final tapped = _hitTest(details.localPosition);
          setState(() {
            selectedIndex = tapped;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey('donut-${widget.animationSeed}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  size: const Size(sizeValue, sizeValue),
                  painter: _DonutChartPainter(
                    data: widget.slices,
                    strokeWidth: strokeWidth,
                    progress: value,
                    selectedIndex: selectedIndex,
                  ),
                );
              },
            ),
            if (selectedIndex != null)
              Builder(
                builder: (context) {
                  final offset = _tooltipOffset(selectedIndex!);
                  final percent = widget.slices[selectedIndex!].value.round();

                  return Positioned(
                    left: offset.dx - 18,
                    top: offset.dy - 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  int? _hitTest(Offset localPosition) {
    final center = const Offset(sizeValue / 2, sizeValue / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt((dx * dx) + (dy * dy));

    final outerRadius = sizeValue / 2;
    final innerRadius = outerRadius - strokeWidth;

    if (distance < innerRadius || distance > outerRadius + 6) {
      return null;
    }

    final angle = math.atan2(dy, dx);
    double adjusted = angle - (-math.pi / 2);
    while (adjusted < 0) {
      adjusted += math.pi * 2;
    }

    final total = widget.slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return null;

    double current = 0;

    for (int i = 0; i < widget.slices.length; i++) {
      final sweep = (widget.slices[i].value / total) * math.pi * 2;
      if (adjusted >= current && adjusted <= current + sweep) {
        return i;
      }
      current += sweep;
    }

    return null;
  }

  Offset _tooltipOffset(int index) {
    final total = widget.slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const Offset(sizeValue / 2, sizeValue / 2);

    double start = -math.pi / 2;

    for (int i = 0; i < index; i++) {
      start += (widget.slices[i].value / total) * math.pi * 2;
    }

    final sweep = (widget.slices[index].value / total) * math.pi * 2;
    final mid = start + (sweep / 2);
    final radius = (sizeValue / 2) - (strokeWidth / 2);

    return Offset(
      sizeValue / 2 + math.cos(mid) * radius,
      sizeValue / 2 + math.sin(mid) * radius,
    );
  }
}

class _InteractiveAreaChart extends StatefulWidget {
  final List<MonthlyDemandPoint> points;
  final int animationSeed;
  final bool isDark;

  const _InteractiveAreaChart({
    required this.points,
    required this.animationSeed,
    required this.isDark,
  });

  @override
  State<_InteractiveAreaChart> createState() => _InteractiveAreaChartState();
}

class _InteractiveAreaChartState extends State<_InteractiveAreaChart> {
  int? selectedIndex;

  @override
  void didUpdateWidget(covariant _InteractiveAreaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationSeed != widget.animationSeed) {
      selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const chartHeight = 165.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pointOffsets =
            _calculateOffsets(width, chartHeight, widget.points);

        return SizedBox(
          width: width,
          height: chartHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final tapped = _nearestPoint(details.localPosition, pointOffsets);
              setState(() {
                selectedIndex = tapped;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('area-${widget.animationSeed}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CustomPaint(
                      size: Size(width, chartHeight),
                      painter: _AreaChartPainter(
                        points: widget.points,
                        progress: value,
                        isDark: widget.isDark,
                        selectedIndex: selectedIndex,
                      ),
                    );
                  },
                ),
                if (selectedIndex != null)
                  Builder(
                    builder: (context) {
                      final point = pointOffsets[selectedIndex!];
                      final monthData = widget.points[selectedIndex!];

                      double left = point.dx - 36;
                      if (left < 0) left = 0;
                      if (left > width - 82) left = width - 82;

                      double top = point.dy - 44;
                      if (top < 4) {
                        top = point.dy + 10;
                      }

                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: 82,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.grey300,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.lightshadow,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                monthData.month,
                                style: const TextStyle(
                                  color: AppColors.blue900,
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Job Postings: ${_formatNumber(monthData.value)}',
                                style: const TextStyle(
                                  color: AppColors.blue900,
                                  fontFamily: 'Inter',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Offset> _calculateOffsets(
    double width,
    double height,
    List<MonthlyDemandPoint> points,
  ) {
    const leftPadding = 28.0;
    const rightPadding = 10.0;
    const topPadding = 10.0;
    const bottomPadding = 26.0;

    final chartWidth = width - leftPadding - rightPadding;
    final chartHeight = height - topPadding - bottomPadding;
    final plotBottom = topPadding + chartHeight;
    final maxPoint = points.isEmpty
        ? 1.0
        : points.map((e) => e.value).reduce(math.max).toDouble();
    final maxY = math.max(20000.0, maxPoint);

    final dxStep = points.length > 1 ? chartWidth / (points.length - 1) : 0.0;

    return List.generate(points.length, (index) {
      final x = leftPadding + (dxStep * index);
      final normalized = (points[index].value / maxY).clamp(0.0, 1.0);
      final y = plotBottom - (normalized * chartHeight);
      return Offset(x, y);
    });
  }

  int? _nearestPoint(Offset tap, List<Offset> points) {
    int? selected;
    double minDistance = 999999;

    for (int i = 0; i < points.length; i++) {
      final d = (tap - points[i]).distance;
      if (d < minDistance) {
        minDistance = d;
        selected = i;
      }
    }

    if (minDistance > 22) return null;
    return selected;
  }
}

class _ProgressMetricRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress;
  final int animationSeed;
  final int animationDelay;

  const _ProgressMetricRow({
    required this.label,
    required this.valueText,
    required this.progress,
    required this.animationSeed,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeProgress = progress.clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.grey100 : AppColors.blue900,
                  fontFamily: 'Inter',
                  fontSize: context.sp(11.5),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: context.w(8)),
            Text(
              valueText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? AppColors.blue200 : AppColors.grey800,
                fontFamily: 'Inter',
                fontSize: context.sp(11.5),
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(8)),
        TweenAnimationBuilder<double>(
          key: ValueKey('$label-$animationSeed'),
          tween: Tween(begin: 0, end: safeProgress),
          duration: Duration(milliseconds: 650 + animationDelay),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(context.r(99)),
              child: Stack(
                children: [
                  Container(
                    height: context.h(7),
                    color: isDark ? AppColors.blue300 : AppColors.grey300,
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: context.h(7),
                      color: isDark
                          ? AppColors.lightBlue500
                          : AppColors.lightBlue700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.w(16),
          height: context.h(16),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: context.w(4)),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? AppColors.grey100 : AppColors.blue900,
            fontFamily: 'Inter',
            fontSize: context.sp(13),
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _AnimatedNumberText extends StatelessWidget {
  final double value;
  final int animationSeed;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final bool formatCommas;
  final TextStyle style;

  const _AnimatedNumberText({
    required this.value,
    required this.animationSeed,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
    this.formatCommas = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('$prefix$value$suffix$animationSeed'),
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        String text;

        if (fractionDigits > 0) {
          text = animatedValue.toStringAsFixed(fractionDigits);
        } else {
          text = animatedValue.round().toString();
        }

        if (formatCommas) {
          if (fractionDigits > 0) {
            final parts = text.split('.');
            parts[0] = _formatNumber(int.tryParse(parts[0]) ?? 0);
            text = parts.join('.');
          } else {
            text = _formatNumber(animatedValue.round());
          }
        }

        return Text(
          '$prefix$text$suffix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

class _ChartSlice {
  final String label;
  final double value;
  final Color color;

  const _ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSlice> data;
  final double strokeWidth;
  final double progress;
  final int? selectedIndex;

  const _DonutChartPainter({
    required this.data,
    required this.strokeWidth,
    required this.progress,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) return;

    final rect = Offset.zero & size;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final slice = data[i];
      final sweepAngle = (slice.value / total) * math.pi * 2 * progress;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == selectedIndex ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;

      canvas.drawArc(
        rect.deflate((i == selectedIndex ? strokeWidth + 4 : strokeWidth) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += (slice.value / total) * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<MonthlyDemandPoint> points;
  final double progress;
  final bool isDark;
  final int? selectedIndex;

  const _AreaChartPainter({
    required this.points,
    required this.progress,
    required this.isDark,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPadding = 28.0;
    const rightPadding = 10.0;
    const topPadding = 10.0;
    const bottomPadding = 26.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final plotLeft = leftPadding;
    final plotTop = topPadding;
    final plotBottom = plotTop + chartHeight;
    final maxPoint = points.map((e) => e.value).reduce(math.max).toDouble();
    final maxY = math.max(20000.0, maxPoint);

    final gridPaint = Paint()
      ..color = isDark ? AppColors.blue300.withOpacity(0.45) : AppColors.grey300
      ..strokeWidth = 1;

    final dottedPaint = Paint()
      ..color = isDark ? AppColors.blue300.withOpacity(0.45) : AppColors.grey300
      ..strokeWidth = 1;

    final axisTextColor = isDark ? AppColors.blue200 : AppColors.grey800;

    const yLabels = ['0k', '5k', '10k', '15k', '20k'];
    for (int i = 0; i < yLabels.length; i++) {
      final ratio = i / (yLabels.length - 1);
      final y = plotBottom - (ratio * chartHeight);

      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final tp = _textPainter(
        yLabels[i],
        TextStyle(
          color: axisTextColor,
          fontSize: 9,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      )..layout();

      tp.paint(canvas, Offset(0, y - (tp.height / 2)));
    }

    final dxStep = points.length > 1 ? chartWidth / (points.length - 1) : 0.0;

    for (int i = 0; i < points.length; i++) {
      final x = plotLeft + (dxStep * i);

      _drawDashedLine(
        canvas,
        Offset(x, plotTop),
        Offset(x, plotBottom),
        dottedPaint,
      );

      final tp = _textPainter(
        points[i].month,
        TextStyle(
          color: axisTextColor,
          fontSize: 9,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      )..layout();

      tp.paint(
        canvas,
        Offset(x - (tp.width / 2), plotBottom + 6),
      );
    }

    final linePath = Path();
    final fillPath = Path();
    final pointOffsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = plotLeft + (dxStep * i);
      final normalized = (points[i].value / maxY).clamp(0.0, 1.0);
      final targetY = plotBottom - (normalized * chartHeight);
      final animatedY = plotBottom - ((plotBottom - targetY) * progress);

      pointOffsets.add(Offset(x, animatedY));

      if (i == 0) {
        linePath.moveTo(x, animatedY);
        fillPath.moveTo(x, plotBottom);
        fillPath.lineTo(x, animatedY);
      } else {
        linePath.lineTo(x, animatedY);
        fillPath.lineTo(x, animatedY);
      }
    }

    final lastX = plotLeft + dxStep * (points.length - 1);
    fillPath.lineTo(lastX, plotBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                AppColors.lightBlue500.withOpacity(0.55),
                AppColors.lightBlue900.withOpacity(0.35),
              ]
            : [
                AppColors.lightBlue600.withOpacity(0.65),
                AppColors.lightBlue100.withOpacity(0.6),
              ],
      ).createShader(
        Rect.fromLTWH(plotLeft, plotTop, chartWidth, chartHeight),
      );

    final linePaint = Paint()
      ..color = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final pointPaint = Paint()
      ..color = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < pointOffsets.length; i++) {
      final point = pointOffsets[i];
      canvas.drawCircle(point, 3, pointPaint);

      if (selectedIndex == i) {
        final selectedPaint = Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 4.5, selectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.selectedIndex != selectedIndex;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashHeight = 4.0;
    const dashSpace = 4.0;

    final totalHeight = end.dy - start.dy;
    double currentY = start.dy;

    while (currentY < end.dy) {
      final nextY = math.min(currentY + dashHeight, start.dy + totalHeight);
      canvas.drawLine(
        Offset(start.dx, currentY),
        Offset(end.dx, nextY),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }
}

TextPainter _textPainter(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  );
}

BoxDecoration _cardDecoration(BuildContext context, bool isDark) {
  return BoxDecoration(
    color: isDark ? AppColors.blue700 : AppColors.grey50,
    borderRadius: BorderRadius.circular(context.r(14)),
    border: Border.all(
      color: isDark
          ? AppColors.grey300.withOpacity(0.24)
          : AppColors.grey800.withOpacity(0.12),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark
            ? AppColors.blue200.withOpacity(0.18)
            : Colors.black.withOpacity(0.08),
        blurRadius: context.r(12),
        spreadRadius: 0,
        offset: Offset(0, context.r(5)),
      ),
    ],
  );
}

TextStyle _valueStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return TextStyle(
    color: isDark ? AppColors.blue200 : AppColors.grey800,
    fontFamily: 'Inter',
    fontSize: context.sp(13),
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
}

String _formatNumber(num value) {
  final text = value.round().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < text.length; i++) {
    final positionFromEnd = text.length - i;
    buffer.write(text[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
