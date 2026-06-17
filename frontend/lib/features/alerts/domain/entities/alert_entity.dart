import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart'; // 👈 أضف ده عشان الـ Color
import '../../../../core/constants/app_colors.dart';

enum AlertType { resume, jobs, interview, plan }

class AlertEntity extends Equatable {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final AlertType type;
  final String? route;

  const AlertEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.route,
  });

  AlertEntity copyWith({bool? isRead}) => AlertEntity(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        type: type,
        route: route,
      );

  // Helper methods for UI
  Color get iconColor {
    switch (type) {
      case AlertType.resume:
        return AppColors.lightBlue500;
      case AlertType.jobs:
        return AppColors.purple500;
      case AlertType.interview:
        return AppColors.green700;
      case AlertType.plan:
        return AppColors.orange500;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  @override
  List<Object?> get props => [id, title, body, createdAt, isRead, type, route];
}
