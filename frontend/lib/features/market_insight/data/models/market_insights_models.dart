class MarketInsightsData {
  final String jobTitle;
  final int jobOpenings;
  final int marketGrowthPercent;
  final double avgExperienceYears;
  final SalaryInsights salaryInsights;
  final List<ExperienceLevelShare> experienceShares;
  final List<SkillDemand> topSkills;
  final List<MonthlyDemandPoint> yearlyDemand;
  final List<GovernorateHiring> topGovernorates;

  const MarketInsightsData({
    required this.jobTitle,
    required this.jobOpenings,
    required this.marketGrowthPercent,
    required this.avgExperienceYears,
    required this.salaryInsights,
    required this.experienceShares,
    required this.topSkills,
    required this.yearlyDemand,
    required this.topGovernorates,
  });

  factory MarketInsightsData.fromJobStatus(MarketJobStatus status) {
    return MarketInsightsData(
      jobTitle: _formatJobTitle(status.job),
      jobOpenings: status.rows < 0 ? 0 : status.rows,
      marketGrowthPercent: 0,
      avgExperienceYears: 0,
      salaryInsights: const SalaryInsights(
        maxMonthlySalary: 0,
        avgMonthlySalary: 0,
        minMonthlySalary: 0,
      ),
      experienceShares: const [
        ExperienceLevelShare(label: 'Entry', value: 0),
        ExperienceLevelShare(label: 'Intermediate', value: 0),
        ExperienceLevelShare(label: 'Senior', value: 0),
        ExperienceLevelShare(label: 'Expert', value: 0),
      ],
      topSkills: const [],
      yearlyDemand: const [],
      topGovernorates: const [],
    );
  }

  factory MarketInsightsData.fromAnalyticsJson(
    Map<String, dynamic> json, {
    String? fallbackJobTitle,
    int? fallbackRows,
  }) {
    final status = json['status']?.toString().toLowerCase() ?? '';
    final job = json['job']?.toString() ?? fallbackJobTitle ?? '';
    final totalJobs = _toInt(json['total_jobs']) ?? fallbackRows ?? 0;

    if (status == 'empty') {
      return MarketInsightsData.fromJobStatus(
        MarketJobStatus(
          job: job,
          done: true,
          loading: false,
          rows: totalJobs,
        ),
      );
    }

    final salaryJson = _asMap(json['salary']);
    final salary = SalaryInsights(
      minMonthlySalary: _safePositiveInt(salaryJson['min']),
      avgMonthlySalary: _safePositiveInt(salaryJson['avg']),
      maxMonthlySalary: _safePositiveInt(salaryJson['max']),
    );

    final experienceDistribution = _asMap(json['experience_distribution']);
    final entry = _toDouble(experienceDistribution['Entry Level']) ?? 0;
    final junior = _toDouble(experienceDistribution['Junior']) ?? 0;
    final mid = _toDouble(experienceDistribution['Mid Level']) ?? 0;
    final senior = _toDouble(experienceDistribution['Senior']) ?? 0;
    final expert = _toDouble(experienceDistribution['Expert']) ?? 0;
    final totalExperience = entry + junior + mid + senior + expert;

    double toShare(double value) {
      if (totalExperience <= 0) return 0;
      return (value / totalExperience) * 100;
    }

    final skills = _parseSkills(json['top_skills']);
    final yearlyDemand = _parseMonthlyDemand(_asMap(json['monthly_demand']));
    final governorates = _parseGovernorates(_asMap(json['governorates']));

    return MarketInsightsData(
      jobTitle: _formatJobTitle(job),
      jobOpenings: totalJobs < 0 ? 0 : totalJobs,
      marketGrowthPercent: (_toDouble(json['market_growth']) ?? 0).round(),
      avgExperienceYears: _safePositiveDouble(json['avg_experience']),
      salaryInsights: salary,
      experienceShares: [
        ExperienceLevelShare(label: 'Entry', value: toShare(entry)),
        ExperienceLevelShare(
            label: 'Intermediate', value: toShare(junior + mid)),
        ExperienceLevelShare(label: 'Senior', value: toShare(senior)),
        ExperienceLevelShare(label: 'Expert', value: toShare(expert)),
      ],
      topSkills: skills.take(5).toList(),
      yearlyDemand: yearlyDemand,
      topGovernorates: governorates.take(5).toList(),
    );
  }

  static List<SkillDemand> _parseSkills(dynamic raw) {
    final skills = <SkillDemand>[];
    if (raw is! List || raw.isEmpty) return skills;

    final counts = raw
        .map((item) => item is Map ? _toInt(item['count']) ?? 0 : 0)
        .toList();
    final maxCount =
        counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

    for (final item in raw) {
      if (item is! Map) continue;
      final skill = item['skill']?.toString().trim() ?? '';
      final count = _toInt(item['count']) ?? 0;
      if (skill.isEmpty || count <= 0) continue;
      final percentage = maxCount <= 0 ? 0 : ((count / maxCount) * 100).round();
      skills
          .add(SkillDemand(skill: skill, percentage: percentage.clamp(0, 100)));
    }
    return skills;
  }

  static List<MonthlyDemandPoint> _parseMonthlyDemand(
      Map<String, dynamic> monthlyDemand) {
    if (monthlyDemand.isEmpty) return [];

    final entries = monthlyDemand.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

    return entries
        .map((entry) => MonthlyDemandPoint(
              month: _formatMonthLabel(entry.key.toString()),
              value: _toInt(entry.value) ?? 0,
            ))
        .where((point) => point.value > 0)
        .toList();
  }

  static List<GovernorateHiring> _parseGovernorates(
      Map<String, dynamic> governoratesJson) {
    final governorates = governoratesJson.entries
        .map((entry) => GovernorateHiring(
              governorate: entry.key.toString(),
              jobs: _toInt(entry.value) ?? 0,
            ))
        .where((item) => item.governorate.trim().isNotEmpty && item.jobs > 0)
        .toList()
      ..sort((a, b) => b.jobs.compareTo(a.jobs));
    return governorates;
  }

  static String _formatMonthLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length >= 7 && trimmed.contains('-')) {
      final parts = trimmed.split('-');
      if (parts.length >= 2) {
        final year = parts[0];
        final monthNumber = int.tryParse(parts[1]);
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        if (monthNumber != null && monthNumber >= 1 && monthNumber <= 12) {
          final shortYear = year.length >= 4 ? year.substring(2) : year;
          return '${months[monthNumber - 1]} $shortYear';
        }
      }
    }
    return trimmed;
  }

  static String _formatJobTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Market Insights';

    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      if (word.toUpperCase() == word && word.length <= 4) return word;
      if (word.contains('/')) {
        return word.split('/').map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        }).join('/');
      }
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}

class SalaryInsights {
  final int maxMonthlySalary;
  final int avgMonthlySalary;
  final int minMonthlySalary;

  const SalaryInsights({
    required this.maxMonthlySalary,
    required this.avgMonthlySalary,
    required this.minMonthlySalary,
  });
}

class ExperienceLevelShare {
  final String label;
  final double value;

  const ExperienceLevelShare({required this.label, required this.value});
}

class SkillDemand {
  final String skill;
  final int percentage;

  const SkillDemand({required this.skill, required this.percentage});
}

class MonthlyDemandPoint {
  final String month;
  final int value;

  const MonthlyDemandPoint({required this.month, required this.value});
}

class GovernorateHiring {
  final String governorate;
  final int jobs;

  const GovernorateHiring({required this.governorate, required this.jobs});
}

class MarketJobsResponse {
  final List<String> jobs;

  const MarketJobsResponse({required this.jobs});

  factory MarketJobsResponse.fromJson(Map<String, dynamic> json) {
    final rawJobs = json['jobs'];
    if (rawJobs is List) {
      return MarketJobsResponse(
          jobs: rawJobs.map((item) => item.toString()).toList());
    }
    return const MarketJobsResponse(jobs: []);
  }
}

class MarketRunResponse {
  final String status;
  final String? message;
  final String? job;
  final int? rows;

  const MarketRunResponse(
      {required this.status, this.message, this.job, this.rows});

  factory MarketRunResponse.fromJson(Map<String, dynamic> json) {
    return MarketRunResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString(),
      job: json['job']?.toString(),
      rows: _toInt(json['rows']),
    );
  }

  bool get isRunning => status.toLowerCase() == 'running';
  bool get isStarted => status.toLowerCase() == 'started';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isRestarted => status.toLowerCase() == 'restarted';
}

class MarketJobStatus {
  final String job;
  final bool done;
  final bool loading;
  final int rows;

  const MarketJobStatus(
      {required this.job,
      required this.done,
      required this.loading,
      required this.rows});

  factory MarketJobStatus.fromJson(Map<String, dynamic> json) {
    return MarketJobStatus(
      job: json['job']?.toString() ?? '',
      done: json['done'] == true,
      loading: json['loading'] == true,
      rows: _toInt(json['rows']) ?? 0,
    );
  }
}

class MarketSystemStatus {
  final int jobIndex;
  final String? lastRun;
  final int totalJobs;
  final bool scrapingRunning;
  final bool batchRunning;

  const MarketSystemStatus({
    required this.jobIndex,
    required this.lastRun,
    required this.totalJobs,
    required this.scrapingRunning,
    required this.batchRunning,
  });

  factory MarketSystemStatus.fromJson(Map<String, dynamic> json) {
    return MarketSystemStatus(
      jobIndex: _toInt(json['job_index']) ?? 0,
      lastRun: json['last_run']?.toString(),
      totalJobs: _toInt(json['total_jobs']) ?? 0,
      scrapingRunning: json['scraping_running'] == true,
      batchRunning: json['batch_running'] == true,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map)
    return value.map((key, value) => MapEntry(key.toString(), value));
  return {};
}

int _safePositiveInt(dynamic value) {
  final parsed = _toInt(value) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

double _safePositiveDouble(dynamic value) {
  final parsed = _toDouble(value) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}
