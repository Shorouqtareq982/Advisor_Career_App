import 'package:equatable/equatable.dart';
import '../../domain/entities/alert_entity.dart';

class AlertsState extends Equatable {
  final bool isLoading;
  final List<AlertEntity> alerts;
  final String? error;

  const AlertsState({
    required this.isLoading,
    required this.alerts,
    this.error,
  });

  factory AlertsState.initial() =>
      const AlertsState(isLoading: true, alerts: []);

  int get unreadCount => alerts.where((a) => !a.isRead).length;

  AlertsState copyWith({
    bool? isLoading,
    List<AlertEntity>? alerts,
    String? error,
  }) {
    return AlertsState(
      isLoading: isLoading ?? this.isLoading,
      alerts: alerts ?? this.alerts,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, alerts, error];
}
