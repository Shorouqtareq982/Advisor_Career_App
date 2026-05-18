import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../domain/entities/interview_entities.dart';
import '../providers/mock_interview_provider.dart';
import '../widgets/mock_interview_dialogs.dart';

class InterviewFeedbackScreen extends ConsumerStatefulWidget {
  const InterviewFeedbackScreen({super.key});

  @override
  ConsumerState<InterviewFeedbackScreen> createState() =>
      _InterviewFeedbackScreenState();
}

class _InterviewFeedbackScreenState
    extends ConsumerState<InterviewFeedbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(mockInterviewProvider);
      if (state.feedbackStatus == FeedbackLoadStatus.idle ||
          state.feedbackStatus == FeedbackLoadStatus.error) {
        ref.read(mockInterviewProvider.notifier).loadFeedbackList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(mockInterviewProvider);
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue900 : AppColors.grey100;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey800;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App Bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.w(8),
                vertical: context.h(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textPrimary,
                      size: context.icon(20),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/branding/growza_logo.png',
                        width: context.logo(40),
                        height: context.logo(40),
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.shield_outlined,
                          color: isDark
                              ? AppColors.lightBlue500
                              : AppColors.lightBlue700,
                          size: context.icon(40),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.w(48)),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: context.h(8)),

                    // Title
                    context.text(
                      'Interview Feedback',
                      style: textTheme.title1Bold.copyWith(color: textPrimary),
                    ),
                    SizedBox(height: context.h(8)),
                    context.text(
                      'Review your past interviews and get personalized insights to improve your performance.',
                      style: textTheme.bodyRegular.copyWith(color: textMuted),
                    ),
                    SizedBox(height: context.h(20)),

                    // Start New Interview button
                    SizedBox(
                      width: double.infinity,
                      height: context.h(52),
                      child: ElevatedButton.icon(
                        onPressed: () => _showSelectJobDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btnColor,
                          foregroundColor:
                              isDark ? AppColors.blue900 : AppColors.grey50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.r(50)),
                          ),
                        ),
                        icon: Icon(
                          Icons.add,
                          size: context.icon(20),
                          color: isDark ? AppColors.blue900 : AppColors.grey50,
                        ),
                        label: context.text(
                          'Start New Interview',
                          style: textTheme.title2Bold.copyWith(
                            color:
                                isDark ? AppColors.blue900 : AppColors.grey50,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.h(20)),

                    // Body
                    Expanded(
                      child: _buildBody(
                        context,
                        state,
                        isDark,
                        textTheme,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MockInterviewState state,
    bool isDark,
    AppTextTheme textTheme,
  ) {
    if (state.feedbackStatus == FeedbackLoadStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.lightBlue500),
      );
    }

    if (state.feedbackList.isEmpty) {
      return _buildEmptyState(context, isDark, textTheme);
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: state.feedbackList.length,
      separatorBuilder: (_, __) => SizedBox(height: context.h(12)),
      itemBuilder: (context, index) {
        final item = state.feedbackList[index];
        return _FeedbackCard(
          feedback: item,
          isDark: isDark,
          onViewDetails: () => context.push(
            '/interview-feedback-detail',
            extra: item.sessionId,
          ),
          onDelete: () => _showDeleteDialog(context, item.sessionId),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    AppTextTheme textTheme,
  ) {
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey800;
    final iconBg = isDark
        ? AppColors.lightBlue900.withOpacity(0.3)
        : AppColors.lightBlue100;
    final iconColor = isDark ? AppColors.lightBlue400 : AppColors.lightBlue700;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: context.w(80),
            height: context.w(80),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(
              Icons.rocket_launch_outlined,
              color: iconColor,
              size: context.icon(40),
            ),
          ),
          SizedBox(height: context.h(20)),
          context.text(
            'No feedback yet.',
            style: textTheme.title2Bold.copyWith(color: textPrimary),
          ),
          SizedBox(height: context.h(8)),
          context.text(
            'Start your first interview to see\npersonalized insights!',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSelectJobDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SelectJobDialog(
        // ── Updated signature: now receives languagePreferred ──────────
        onStart: (roleName, roleId, sessionType, languagePreferred) {
          context.push('/interview-session', extra: {
            'roleName': roleName,
            'roleId': roleId,
            'sessionType': sessionType,
            'languagePreferred': languagePreferred,
          });
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String sessionId) {
    showDialog(
      context: context,
      builder: (_) => DeleteInterviewFeedbackDialog(
        onConfirm: () =>
            ref.read(mockInterviewProvider.notifier).deleteFeedback(sessionId),
      ),
    );
  }
}

// ─── Feedback Card ────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final InterviewFeedbackSummary feedback;
  final bool isDark;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  const _FeedbackCard({
    required this.feedback,
    required this.isDark,
    required this.onViewDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.appTextTheme;
    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.3) : AppColors.grey300;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final dateColor = isDark ? AppColors.grey300 : AppColors.grey700;
    final isBehavioral =
        feedback.sessionType == InterviewSessionType.behavioral;

    return Container(
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Role + Session Type Badge ───────────────────
          Row(
            children: [
              Expanded(
                child: context.text(
                  feedback.roleName,
                  style: textTheme.title2Bold.copyWith(color: textPrimary),
                ),
              ),
              SizedBox(width: context.w(12)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(10),
                  vertical: context.h(4),
                ),
                decoration: BoxDecoration(
                  color: isBehavioral
                      ? AppColors.lightBlue500.withOpacity(0.15)
                      : AppColors.purple500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.r(20)),
                ),
                child: context.text(
                  isBehavioral ? 'Behavioral' : 'Technical',
                  style: textTheme.captionBold.copyWith(
                    color: isBehavioral
                        ? AppColors.lightBlue500
                        : AppColors.purple500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(10)),

          // ── Date ─────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: dateColor,
                size: context.icon(14),
              ),
              SizedBox(width: context.w(4)),
              context.text(
                DateFormat('MMMM d, y').format(feedback.createdAt),
                style: textTheme.captionRegular.copyWith(color: dateColor),
              ),
            ],
          ),

          if (feedback.languagePreferred != null) ...[
            SizedBox(height: context.h(6)),
            Row(
              children: [
                Icon(
                  Icons.language_outlined,
                  color: dateColor,
                  size: context.icon(14),
                ),
                SizedBox(width: context.w(4)),
                context.text(
                  feedback.languagePreferred == 'ar'
                      ? 'Arabic session'
                      : 'English session',
                  style: textTheme.captionRegular.copyWith(color: dateColor),
                ),
              ],
            ),
          ],
          SizedBox(height: context.h(12)),

          // ── Actions ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: context.h(40),
                  child: ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.lightBlue500
                          : AppColors.lightBlue700,
                      foregroundColor: AppColors.blue700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.r(50)),
                      ),
                    ),
                    child: context.text(
                      'View Details',
                      style: textTheme.bodyBold.copyWith(
                        color: AppColors.blue700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(8)),
              Container(width: 1, height: context.h(40), color: borderColor),
              SizedBox(width: context.w(8)),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: context.w(40),
                  height: context.h(40),
                  decoration: BoxDecoration(
                    color: AppColors.red500,
                    borderRadius: BorderRadius.circular(context.r(8)),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: context.icon(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
