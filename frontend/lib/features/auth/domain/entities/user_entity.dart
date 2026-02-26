import 'dart:convert';

class AppUser {
  final String id;
  final String? email;
  final String? username;
  final String? phone;
  final String? avatarUrl;
  final String? provider;
  final String? topSkills;
  final String? domain;
  final String? linkedinUrl;
  final String? cvUrl;
  final String? preferredLocation;
  final String? interestedTracks;
  final String? jobTitle;
  final String? joinTime;
  final List<String> workType;
  final List<String> workLocation;
  final List<String> jobPlatforms;
  final String? jobAlertsFrequency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? hasCompletedOnboarding;

  const AppUser({
    required this.id,
    this.email,
    this.username,
    this.phone,
    this.avatarUrl,
    this.provider,
    this.topSkills,
    this.domain,
    this.linkedinUrl,
    this.cvUrl,
    this.preferredLocation,
    this.interestedTracks,
    this.jobTitle,
    this.joinTime,
    this.workType = const [],
    this.workLocation = const [],
    this.jobPlatforms = const [],
    this.jobAlertsFrequency,
    this.createdAt,
    this.updatedAt,
    this.hasCompletedOnboarding,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      provider: json['provider'] as String?,
      topSkills: json['top_skills'] as String?,
      domain: json['domain'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
      cvUrl: json['cv_url'] as String?,
      preferredLocation: json['preferred_location'] as String?,
      interestedTracks: json['interested_tracks'] as String?,
      jobTitle: json['job_title'] as String?,
      joinTime: json['join_time'] as String?,
      workType: AppUser._parseStringList(json['work_type']),
      workLocation: AppUser._parseStringList(json['work_location']),
      jobPlatforms: AppUser._parseStringList(json['job_platforms']),
      jobAlertsFrequency: json['job_alerts_frequency'] as String? ?? 'daily',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool?,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return List<String>.from(value);
    }

    if (value is String) {
      try {
        if (value.trim().isEmpty) return [];

        final parsed = jsonDecode(value);
        if (parsed is List) {
          return List<String>.from(parsed);
        }
        return [];
      } catch (e) {
        print('  Error parsing string list: $e');
        return [];
      }
    }

    return [];
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'phone': phone,
      'avatar_url': avatarUrl,
      'provider': provider,
      'top_skills': topSkills,
      'domain': domain,
      'linkedin_url': linkedinUrl,
      'cv_url': cvUrl,
      'preferred_location': preferredLocation,
      'interested_tracks': interestedTracks,
      'job_title': jobTitle,
      'join_time': joinTime,
      'work_type': workType,
      'work_location': workLocation,
      'job_platforms': jobPlatforms,
      'job_alerts_frequency': jobAlertsFrequency,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'has_completed_onboarding': hasCompletedOnboarding,
    };
  }

  bool get isProfileComplete =>
      username != null &&
      username!.isNotEmpty &&
      topSkills != null &&
      topSkills!.isNotEmpty;

  /// Copy with method
  AppUser copyWith({
    String? id,
    String? email,
    String? username,
    String? phone,
    String? avatarUrl,
    String? provider,
    String? topSkills,
    String? domain,
    String? linkedinUrl,
    String? cvUrl,
    String? preferredLocation,
    String? interestedTracks,
    String? jobTitle,
    String? joinTime,
    List<String>? workType,
    List<String>? workLocation,
    List<String>? jobPlatforms,
    String? jobAlertsFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasCompletedOnboarding,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      provider: provider ?? this.provider,
      topSkills: topSkills ?? this.topSkills,
      domain: domain ?? this.domain,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      cvUrl: cvUrl ?? this.cvUrl,
      preferredLocation: preferredLocation ?? this.preferredLocation,
      interestedTracks: interestedTracks ?? this.interestedTracks,
      jobTitle: jobTitle ?? this.jobTitle,
      joinTime: joinTime ?? this.joinTime,
      workType: workType ?? this.workType,
      workLocation: workLocation ?? this.workLocation,
      jobPlatforms: jobPlatforms ?? this.jobPlatforms,
      jobAlertsFrequency: jobAlertsFrequency ?? this.jobAlertsFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, username: $username, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
