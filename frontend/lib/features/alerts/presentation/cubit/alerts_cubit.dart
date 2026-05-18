import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_alerts.dart';
import '../../domain/usecases/mark_all_read.dart';
import '../../domain/usecases/mark_alert_read.dart';
import 'alerts_state.dart';

class AlertsCubit extends Cubit<AlertsState> {
  final GetAlerts getAlerts;
  final MarkAllRead markAllRead;
  final MarkAlertRead markAlertRead;

  AlertsCubit({
    required this.getAlerts,
    required this.markAllRead,
    required this.markAlertRead,
  }) : super(AlertsState.initial());

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      final items = await getAlerts();
      final sorted = [...items]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(state.copyWith(isLoading: false, alerts: sorted));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> onMarkAllRead() async {
    try {
      final items = await markAllRead();
      final sorted = [...items]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(state.copyWith(alerts: sorted));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onOpenAlert(String id) async {
    try {
      final items = await markAlertRead(id);
      final sorted = [...items]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(state.copyWith(alerts: sorted));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> markAll() => onMarkAllRead();
  Future<void> markRead(String id) => onOpenAlert(id);
}
