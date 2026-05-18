import '../../domain/entities/alert_entity.dart';

class AlertModel extends AlertEntity {
  const AlertModel({
    required super.id,
    required super.title,
    required super.body,
    required super.createdAt,
    required super.isRead,
    required super.type,
    super.route,
  });

  @override
  AlertModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    AlertType? type,
    String? route,
  }) {
    return AlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      route: route ?? this.route,
    );
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.parse(
        (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      ).toLocal(),
      isRead: (json['isRead'] ?? false) == true,
      type: _parseType((json['type'] ?? 'jobs').toString()),
      route: json['route'] as String?,
    );
  }

  factory AlertModel.fromSupabase(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      ).toLocal(),
      isRead: (json['is_read'] ?? false) == true,
      type: _parseType((json['type'] ?? 'jobs').toString()),
      route: json['route'] as String?,
    );
  }

  static AlertType _parseType(String v) {
    switch (v.toLowerCase()) {
      case 'resume':
        return AlertType.resume;
      case 'jobs':
        return AlertType.jobs;
      case 'interview':
        return AlertType.interview;
      case 'plan':
        return AlertType.plan;
      default:
        return AlertType.jobs;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isRead': isRead,
      'type': type.toString().split('.').last,
      'route': route,
    };
  }
}
