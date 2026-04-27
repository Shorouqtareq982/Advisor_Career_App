import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/job_model.dart';
import '../../domain/entities/job_entity.dart';

class JobMatchingRepository {
  final Dio _dio = apiClient.dio;

  // ── Endpoints (will be confirmed when backend sends them) ──────────────────
  static const String _base = '/api/v1/job_matching';
  static const String _recommended = '$_base/recommendations';
  static const String _saved = '$_base/saved';
  static const String _save = '$_base/save'; // POST  {job_id}
  static const String _unsave = '$_base/unsave'; // DELETE {job_id}
  static const String _rate = '$_base/rate'; // POST  {job_id, rating}
  static const String _markSeen = '$_base/seen'; // POST  {job_id}
  static const String _preferences = '/api/v1/job_preferences'; // GET/POST

  // ── Mock data (used until backend endpoints are ready) ────────────────────
  static final List<JobEntity> _mockJobs = [
    JobEntity(
      id: '1',
      title: 'UI/UX Designer',
      company: 'Digital Creative Studio',
      location: 'New York',
      workType: 'Full-time',
      workLocation: 'Hybrid',
      jobUrl: 'https://example.com/job/1',
      jobDescription:
          'We are looking for an enthusiastic and motivated E-commerce Web Design Intern to join our growing team. This is an excellent opportunity for recent graduates passionate about e-commerce and web development to gain hands-on experience. The intern will assist our development team in designing, updating, and maintaining e-commerce websites on WordPress, Shopify and will be introduced to regional platforms like Salla and Zid.\n\nRequirements:\n• Graduates from the Faculty of Computer Science and Information Systems will be given priority.\n• Previous experience in website design on any platform.\n• Proficiency in Microsoft Office Tools.',
      requiredSkills: [
        'Figma',
        'Wireframing',
        'Prototyping',
        'Design Systems',
        'User Research'
      ],
      postedAt: DateTime.now().subtract(const Duration(hours: 1)),
      isSaved: false,
      isNew: true,
    ),
    JobEntity(
      id: '2',
      title: 'UI/UX Designer',
      company: 'Ulemt',
      location: 'Los Angeles',
      workType: 'Part-time',
      workLocation: 'Remote',
      jobUrl: 'https://example.com/job/2',
      jobDescription:
          'We are looking for a talented UI/UX designer to join our remote team. You will work closely with product managers and developers to create beautiful, user-friendly interfaces.',
      requiredSkills: ['Figma', 'Adobe XD', 'User Research', 'Prototyping'],
      postedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isSaved: false,
      isNew: true,
    ),
    JobEntity(
      id: '3',
      title: 'Product Designer',
      company: 'Tech Innovations',
      location: 'San Francisco',
      workType: 'Full-time',
      workLocation: 'Onsite',
      jobUrl: 'https://example.com/job/3',
      jobDescription:
          'Join our product team as a Product Designer and help shape the future of our platform.',
      requiredSkills: [
        'Figma',
        'Design Systems',
        'User Testing',
        'Interaction Design'
      ],
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      isSaved: false,
      isNew: false,
    ),
  ];

  // ── Get recommended jobs ───────────────────────────────────────────────────
  Future<List<JobEntity>> getRecommendedJobs() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}$_recommended',
      );
      final List<dynamic> data = response.data as List<dynamic>? ?? [];
      return data
          .map((item) =>
              JobModel.fromJson(item as Map<String, dynamic>).toEntity())
          .toList();
    } catch (_) {
      // Return mock data until API is ready
      return _mockJobs;
    }
  }

  // ── Get saved jobs ─────────────────────────────────────────────────────────
  Future<List<JobEntity>> getSavedJobs() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}$_saved',
      );
      final List<dynamic> data = response.data as List<dynamic>? ?? [];
      return data
          .map((item) =>
              JobModel.fromJson(item as Map<String, dynamic>).toEntity())
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Save / unsave a job ────────────────────────────────────────────────────
  Future<void> saveJob(String jobId) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}$_save',
        data: {'job_id': jobId},
      );
    } catch (_) {
      // silently fail in mock mode
    }
  }

  Future<void> unsaveJob(String jobId) async {
    try {
      await _dio.delete(
        '${ApiConstants.baseUrl}$_unsave',
        data: {'job_id': jobId},
      );
    } catch (_) {}
  }

  // ── Rate a job ─────────────────────────────────────────────────────────────
  Future<void> rateJob({required String jobId, required int rating}) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}$_rate',
        data: {'job_id': jobId, 'rating': rating},
      );
    } catch (_) {}
  }

  // ── Mark job as seen (removes "New" badge) ─────────────────────────────────
  Future<void> markJobSeen(String jobId) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}$_markSeen',
        data: {'job_id': jobId},
      );
    } catch (_) {}
  }

  // ── Check if preferences are complete ─────────────────────────────────────
  /// This checks from the auth user directly — no API call needed.
  /// Used in provider to decide whether to show preferences screen first.
  Future<bool> arePreferencesComplete({
    required String? jobTitle,
    required List<String> workType,
    required List<String> workLocation,
    required List<String> jobPlatforms,
    required String? cvUrl,
  }) async {
    return jobTitle != null &&
        jobTitle.isNotEmpty &&
        workType.isNotEmpty &&
        workLocation.isNotEmpty &&
        jobPlatforms.isNotEmpty &&
        cvUrl != null &&
        cvUrl.isNotEmpty;
  }
}
