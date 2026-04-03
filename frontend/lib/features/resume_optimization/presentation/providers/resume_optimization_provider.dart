import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/resume_optimization_repository.dart';
import '../../domain/entities/resume_report_entity.dart';

// ─── State ───────────────────────────────────────────────────────────────────

enum AnalysisStatus { idle, uploading, processing, success, error }

class ResumeOptimizationState {
  final List<ResumeReportSummary> reports;
  final bool isLoadingReports;
  final AnalysisStatus analysisStatus;
  final String? errorMessage;
  final String? latestReportId;
  final ResumeReportEntity? currentReport;
  final bool isLoadingReport;
  final bool isDeletingReport;

  /// Name saved at upload time: job title (if JD provided) or CV filename
  final String? pendingReportName;

  const ResumeOptimizationState({
    this.reports = const [],
    this.isLoadingReports = false,
    this.analysisStatus = AnalysisStatus.idle,
    this.errorMessage,
    this.latestReportId,
    this.currentReport,
    this.isLoadingReport = false,
    this.isDeletingReport = false,
    this.pendingReportName,
  });

  ResumeOptimizationState copyWith({
    List<ResumeReportSummary>? reports,
    bool? isLoadingReports,
    AnalysisStatus? analysisStatus,
    String? errorMessage,
    String? latestReportId,
    ResumeReportEntity? currentReport,
    bool? isLoadingReport,
    bool? isDeletingReport,
    String? pendingReportName,
    bool clearError = false,
    bool clearLatestReportId = false,
    bool clearCurrentReport = false,
    bool clearPendingReportName = false,
  }) {
    return ResumeOptimizationState(
      reports: reports ?? this.reports,
      isLoadingReports: isLoadingReports ?? this.isLoadingReports,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      latestReportId:
          clearLatestReportId ? null : (latestReportId ?? this.latestReportId),
      currentReport:
          clearCurrentReport ? null : (currentReport ?? this.currentReport),
      isLoadingReport: isLoadingReport ?? this.isLoadingReport,
      isDeletingReport: isDeletingReport ?? this.isDeletingReport,
      pendingReportName: clearPendingReportName
          ? null
          : (pendingReportName ?? this.pendingReportName),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ResumeOptimizationNotifier
    extends StateNotifier<ResumeOptimizationState> {
  final ResumeOptimizationRepository _repository;

  /// Map of reportId → display name, persisted to SharedPreferences
  final Map<String, String> _savedNames = {};
  static const _prefsKey = 'cv_report_names';
  static const _cachedReportsKey = 'cached_reports';

  ResumeOptimizationNotifier(this._repository)
      : super(const ResumeOptimizationState()) {
    _loadSavedNames();
  }

  Future<void> _loadSavedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      _savedNames.addAll(map);
    }
  }

  Future<void> _persistSavedNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_savedNames));
  }

  Future<void> loadReports() async {
    state = state.copyWith(isLoadingReports: true, clearError: true);
    try {
      final reports = await _repository.getUserReports();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final patched = reports.map((r) {
        final saved = _savedNames[r.reportId];
        return saved != null ? r.copyWith(cvName: saved) : r;
      }).toList();

      await _cacheReports(patched);
      state = state.copyWith(
        reports: patched,
        isLoadingReports: false,
      );
    } catch (e) {
      final cached = await _loadCachedReports();
      state = state.copyWith(
        reports: cached,
        isLoadingReports: false,
        errorMessage: cached.isEmpty ? _parseError(e) : null,
      );
    }
  }

  Future<void> analyzeCV({
    required File cvFile,
    String? jobDescription,
  }) async {
    // Build display name before upload
    final displayName = _buildDisplayName(cvFile, jobDescription);

    state = state.copyWith(
      analysisStatus: AnalysisStatus.uploading,
      pendingReportName: displayName,
      clearError: true,
      clearLatestReportId: true,
    );
    try {
      state = state.copyWith(analysisStatus: AnalysisStatus.processing);

      final result = await _repository.analyzeCV(
        cvFile: cvFile,
        jobDescription: jobDescription,
      );

      final reportId = result['report_id'] as String?;
      // Persist the display name for this specific report
      if (reportId != null) {
        _savedNames[reportId] = displayName;
        await _persistSavedNames();
      }

      state = state.copyWith(
        analysisStatus: AnalysisStatus.success,
        latestReportId: reportId,
      );
      await loadReports();
    } catch (e) {
      state = state.copyWith(
        analysisStatus: AnalysisStatus.error,
        errorMessage: _parseError(e),
        clearPendingReportName: true,
      );
    }
  }

  Future<void> loadReport(String reportId) async {
    state = state.copyWith(isLoadingReport: true, clearError: true);
    try {
      final report = await _repository.getReport(reportId);
      await _cacheFullReport(report);
      state = state.copyWith(currentReport: report, isLoadingReport: false);
    } catch (e) {
      final cached = await _loadCachedFullReport(reportId);
      if (cached != null) {
        state = state.copyWith(currentReport: cached, isLoadingReport: false);
      } else {
        state = state.copyWith(
          isLoadingReport: false,
          errorMessage: _parseError(e),
        );
      }
    }
  }

  Future<void> deleteReport(String reportId) async {
    state = state.copyWith(isDeletingReport: true, clearError: true);
    try {
      await _repository.deleteReport(reportId);
      _savedNames.remove(reportId);
      await _persistSavedNames();
      final updated =
          state.reports.where((r) => r.reportId != reportId).toList();
      state = state.copyWith(reports: updated, isDeletingReport: false);
    } catch (e) {
      state = state.copyWith(
        isDeletingReport: false,
        errorMessage: _parseError(e),
      );
    }
  }

  void resetAnalysisStatus() {
    state = state.copyWith(
      analysisStatus: AnalysisStatus.idle,
      clearError: true,
      clearLatestReportId: true,
    );
  }

  void clearCurrentReport() {
    state = state.copyWith(clearCurrentReport: true);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _cacheReports(List<ResumeReportSummary> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = reports
          .map((r) => {
                'reportId': r.reportId,
                'cvName': r.cvName,
                'atsScore': r.atsScore,
                'contentQualityScore': r.contentQualityScore,
                'jobMatchScore': r.jobMatchScore,
                'createdAt': r.createdAt.toIso8601String(),
              })
          .toList();
      await prefs.setString(_cachedReportsKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<List<ResumeReportSummary>> _loadCachedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedReportsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => ResumeReportSummary(
                reportId: item['reportId'] as String,
                cvName: item['cvName'] as String,
                atsScore: item['atsScore'] as int,
                contentQualityScore: item['contentQualityScore'] as int,
                jobMatchScore: item['jobMatchScore'] as int?,
                createdAt: DateTime.parse(item['createdAt'] as String),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheFullReport(ResumeReportEntity report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'full_report_${report.reportId}', jsonEncode(report.toJson()));
    } catch (_) {}
  }

  Future<ResumeReportEntity?> _loadCachedFullReport(String reportId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('full_report_$reportId');
      if (raw == null) return null;
      return ResumeReportEntity.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Builds a display name from upload inputs:
  /// - JD provided  → first non-empty line (job title)
  /// - No JD        → CV filename without extension and prefix cleanup
  String _buildDisplayName(File cvFile, String? jobDescription) {
    if (jobDescription != null && jobDescription.trim().isNotEmpty) {
      // Use first non-empty line as job title, apply Title Case
      final firstLine = jobDescription
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => '');
      if (firstLine.isNotEmpty && firstLine.length <= 80) {
        return _toTitleCase(firstLine);
      }
    }

    // Fallback: CV filename with Title Case
    final filename = cvFile.path.split('/').last.split('\\').last;
    final nameOnly = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    return _toTitleCase(
        nameOnly.replaceAll('_', ' ').replaceAll('-', ' ').trim());
  }

  /// Converts a string to Title Case (e.g. "data analst" → "Data Analst")
  String _toTitleCase(String input) {
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _parseError(Object e) {
    final msg = e.toString();

    // Network / connectivity
    if (msg.contains('SocketException') ||
        msg.contains('NetworkException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('Network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Timeout
    if (msg.contains('TimeoutException') ||
        msg.contains('ReadTimeout') ||
        msg.contains('timed out')) {
      return 'Connection timed out. Please check your network and try again.';
    }

    // Auth
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Your session has expired. Please sign in again.';
    }

    // File issues
    if (msg.contains('413')) {
      return 'File is too large. Please use a file under 10 MB.';
    }
    if (msg.contains('400') || msg.contains('Bad Request')) {
      return 'Invalid file format. Please upload a PDF or DOCX file.';
    }
    if (msg.contains('415') || msg.contains('Unsupported Media')) {
      return 'Unsupported file type. Please upload a PDF or DOCX file.';
    }

    // Server errors
    if (msg.contains('503') || msg.contains('Service Unavailable')) {
      return 'Service is temporarily unavailable. Please try again later.';
    }
    if (msg.contains('502') || msg.contains('Bad Gateway')) {
      return 'Server error. Please try again in a few moments.';
    }
    if (msg.contains('500') || msg.contains('Internal Server Error')) {
      return 'A server error occurred. Please try again.';
    }

    // Cloudinary / upload specific
    if (msg.contains('cloudinary') ||
        msg.contains('Cloudinary') ||
        msg.contains('upload')) {
      return 'Failed to upload your file. Please check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final resumeOptimizationRepositoryProvider =
    Provider<ResumeOptimizationRepository>(
  (ref) => ResumeOptimizationRepository(),
);

final resumeOptimizationProvider =
    StateNotifierProvider<ResumeOptimizationNotifier, ResumeOptimizationState>(
  (ref) => ResumeOptimizationNotifier(
    ref.read(resumeOptimizationRepositoryProvider),
  ),
);
