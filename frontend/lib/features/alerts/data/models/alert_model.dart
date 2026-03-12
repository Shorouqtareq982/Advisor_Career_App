import '../../domain/entities/alert_entity.dart';

class AlertModel extends AlertEntity {
  const AlertModel({
    required super.id,
    required super.title,
    required super.body,
    required super.createdAt,
    required super.isRead,
    required super.type,
  });

  @override
  AlertModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    AlertType? type,
  }) {
    return AlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.parse(
        (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      isRead: (json['isRead'] ?? false) == true,
      type: _parseType((json['type'] ?? 'jobs').toString()),
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
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'type': type.toString().split('.').last,
    };
  }
}
