import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:growza/core/constants/app_colors.dart';
import 'package:growza/core/extensions/responsive_extension.dart';

import '../../../home/presentation/widgets/home_bottom_nav.dart';
import '../../data/datasources/alerts_local_datasource.dart';
import '../../data/repositories/alerts_repository_impl.dart';
import '../../domain/usecases/get_alerts.dart';
import '../../domain/usecases/mark_all_read.dart';
import '../../domain/usecases/mark_alert_read.dart';
import '../cubit/alerts_cubit.dart';
import '../cubit/alerts_state.dart';
import '../widgets/alerts_app_bar.dart';
import '../widgets/alerts_header_row.dart';
import '../widgets/alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AlertsCubit _cubit;
  late final _LifecycleObserver _observer;

  @override
  void initState() {
    super.initState();
    final ds = AlertsLocalDataSourceImpl();
    final repo = AlertsRepositoryImpl(ds);
    _cubit = AlertsCubit(
      getAlerts: GetAlerts(repo),
      markAllRead: MarkAllRead(repo),
      markAlertRead: MarkAlertRead(repo),
    )..load();

    _observer = _LifecycleObserver(_cubit);
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.backgroundAdaptive(context),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: context.contentConstraints,
              child: BlocBuilder<AlertsCubit, AlertsState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.error != null) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.w(16)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimaryAdaptive(context),
                                fontFamily: 'Inter',
                                fontSize: context.sp(14),
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: context.h(12)),
                            SizedBox(
                              height: context.h(44),
                              child: ElevatedButton(
                                onPressed: _cubit.load,
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: context.sp(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final alerts = state.alerts;

                  return Column(
                    children: [
                      AlertsAppBar(
                        onBack: () => context.go('/home'),
                      ),
                      SizedBox(height: context.h(10)),
                      Text(
                        'Alerts',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(23),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryAdaptive(context),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: context.h(18)),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: context.w(16)),
                        child: AlertsHeaderRow(
                          unreadCount: state.unreadCount,
                          onMarkAllRead: _cubit.onMarkAllRead,
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _cubit.load,
                          child: alerts.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(height: context.h(80)),
                                    Center(
                                      child: Text(
                                        'No alerts yet',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: context.sp(14),
                                          color: AppColors.textMutedAdaptive(
                                              context),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.symmetric(
                                          horizontal: context.w(16))
                                      .copyWith(bottom: context.h(16)),
                                  itemCount: alerts.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: context.h(16)),
                                  itemBuilder: (_, i) {
                                    final alert = alerts[i];
                                    return AlertCard(
                                      alert: alert,
                                      onTap: () {
                                        _cubit.onOpenAlert(alert.id);
                                        if (alert.route != null) {
                                          if (alert.route ==
                                              '/interview-feedback-detail') {
                                            final sessionId = alert.id
                                                .replaceFirst('interview_', '');
                                            context.push(alert.route!,
                                                extra: sessionId);
                                          } else {
                                            context.push(alert.route!);
                                          }
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: const HomeBottomNav(currentRoute: '/alerts'),
      ),
    );
  }
}

// ── Lifecycle observer ────────────────────────────────────────────────────────

class _LifecycleObserver extends WidgetsBindingObserver {
  final AlertsCubit cubit;
  _LifecycleObserver(this.cubit);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      cubit.load();
    }
  }
}
