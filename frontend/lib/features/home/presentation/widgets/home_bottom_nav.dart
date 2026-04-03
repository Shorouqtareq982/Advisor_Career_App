import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class HomeBottomNav extends StatelessWidget {
  final String currentRoute;

  const HomeBottomNav({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        height: context.h(70),
        padding: EdgeInsets.only(
          left: context.w(24),
          right: context.w(24),
          bottom: context.h(3),
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.blue900 : AppColors.textDark,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.blue200.withOpacity(0.3)
                  : AppColors.grey800.withOpacity(0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.blue200.withOpacity(0.25)
                  : AppColors.grey800.withOpacity(0.25),
              offset: const Offset(0, 0),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: context.contentConstraints,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  iconBuilder: (stroke, fill, w, h) => _HomeIcon(
                      strokeColor: stroke,
                      fillColor: fill,
                      width: w,
                      height: h),
                  label: 'Home',
                  isActive: currentRoute == '/home',
                  onTap: () => context.go('/home'),
                  isDark: isDark,
                  nativeW: 31,
                  nativeH: 27,
                ),
                _NavItem(
                  iconBuilder: (stroke, fill, w, h) => _JobsIcon(
                      strokeColor: stroke,
                      fillColor: fill,
                      width: w,
                      height: h),
                  label: 'Jobs',
                  isActive: currentRoute == '/jobs',
                  onTap: () => context.go('/jobs'),
                  isDark: isDark,
                  nativeW: 24,
                  nativeH: 24,
                ),
                _NavItem(
                  iconBuilder: (stroke, fill, w, h) => _AlertsIcon(
                      strokeColor: stroke,
                      fillColor: fill,
                      width: w,
                      height: h),
                  label: 'Alerts',
                  isActive: currentRoute == '/alerts',
                  onTap: () => context.go('/alerts'),
                  isDark: isDark,
                  nativeW: 24,
                  nativeH: 24,
                ),
                _NavItem(
                  iconBuilder: (stroke, fill, w, h) => _ProfileIcon(
                      strokeColor: stroke,
                      fillColor: fill,
                      width: w,
                      height: h),
                  label: 'Profile',
                  isActive: currentRoute == '/profile',
                  onTap: () => context.go('/profile'),
                  isDark: isDark,
                  nativeW: 18,
                  nativeH: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final Widget Function(Color strokeColor, Color fillColor, double w, double h)
      iconBuilder;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final double nativeW;
  final double nativeH;

  const _NavItem({
    required this.iconBuilder,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
    required this.nativeW,
    required this.nativeH,
  });

  @override
  Widget build(BuildContext context) {
    final double finalW = isActive ? context.w(31) : context.w(24);
    final double finalH = isActive ? context.h(27) : context.h(24);

    final Color activeStrokeColor =
        isDark ? const Color(0xFFEBEBEB) : const Color(0xFF0F111D);
    final Color activeFillColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final Color inactiveStrokeColor =
        isDark ? AppColors.blue200 : const Color(0xFF686868);
    final Color inactiveFillColor =
        isDark ? const Color(0xFF0F111D) : const Color(0xFFEBEBEB);

    final Color strokeColor =
        isActive ? activeStrokeColor : inactiveStrokeColor;
    final Color fillColor = isActive ? activeFillColor : inactiveFillColor;
    final Color labelColor = isActive ? fillColor : strokeColor;

    final TextStyle labelStyle = isActive
        ? context.appTextTheme.title2Bold
        : context.appTextTheme.bodyRegular;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.r(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconBuilder(strokeColor, fillColor, finalW, finalH),
            SizedBox(height: context.h(2)),
            Text(
              label,
              style: context
                  .responsiveText(labelStyle)
                  .copyWith(color: labelColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home Icon — viewBox 31×27 ─────────────────────────────────────────────────

class _HomeIcon extends StatelessWidget {
  final Color strokeColor;
  final Color fillColor;
  final double width;
  final double height;
  const _HomeIcon({
    required this.strokeColor,
    required this.fillColor,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter:
              _HomeIconPainter(strokeColor: strokeColor, fillColor: fillColor),
        ),
      );
}

class _HomeIconPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  const _HomeIconPainter({required this.strokeColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 31, size.height / 27);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeMiterLimit = 10
      ..strokeJoin = StrokeJoin.miter;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final fill = Path()
      ..moveTo(5, 26)
      ..lineTo(5.45652, 11.6481)
      ..lineTo(15.5, 1)
      ..lineTo(25.5435, 11.6481)
      ..lineTo(26, 26)
      ..lineTo(18.65, 26)
      ..lineTo(18.65, 15.1304)
      ..lineTo(12.35, 15.1304)
      ..lineTo(12.35, 26)
      ..close();
    canvas.drawPath(fill, fillPaint);

    // Stroke — roof
    final roof = Path()
      ..moveTo(1, 16)
      ..lineTo(15.5, 1)
      ..lineTo(30, 16);
    canvas.drawPath(roof, strokePaint);

    // Stroke — house outline
    final house = Path()
      ..moveTo(5.45652, 11.6481)
      ..lineTo(5, 26)
      ..lineTo(12.35, 26)
      ..lineTo(12.35, 15.1304)
      ..lineTo(18.65, 15.1304)
      ..lineTo(18.65, 26)
      ..lineTo(26, 26)
      ..lineTo(25.5435, 11.6481)
      ..lineTo(15.5, 1)
      ..close();
    canvas.drawPath(house, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HomeIconPainter old) =>
      old.strokeColor != strokeColor || old.fillColor != fillColor;
}

// ── Jobs Icon ─────────────────────────────────────────────────

class _JobsIcon extends StatelessWidget {
  final Color strokeColor;
  final Color fillColor;
  final double width;
  final double height;
  const _JobsIcon({
    required this.strokeColor,
    required this.fillColor,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter:
              _JobsIconPainter(strokeColor: strokeColor, fillColor: fillColor),
        ),
      );
}

class _JobsIconPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  const _JobsIconPainter({required this.strokeColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Fill — bag body
    final bodyFill = Path();
    bodyFill.moveTo(2, 9);
    bodyFill.cubicTo(2, 7.89543, 2.89543, 7, 4, 7);
    bodyFill.lineTo(20, 7);
    bodyFill.cubicTo(21.1046, 7, 22, 7.89543, 22, 9);
    bodyFill.lineTo(22, 20);
    bodyFill.cubicTo(22, 21.1046, 21.1046, 22, 20, 22);
    bodyFill.lineTo(4, 22);
    bodyFill.cubicTo(2.89543, 22, 2, 21.1046, 2, 20);
    bodyFill.lineTo(2, 9);
    bodyFill.close();

    canvas.drawPath(bodyFill, fillPaint);
    canvas.drawPath(bodyFill, strokePaint);

    // Stroke — handle
    final handle = Path();
    handle.moveTo(16, 7);
    handle.lineTo(16, 4);
    handle.cubicTo(16, 2.89543, 15.1046, 2, 14, 2);
    handle.lineTo(10, 2);
    handle.cubicTo(8.89543, 2, 8, 2.89543, 8, 4);
    handle.lineTo(8, 7);
    canvas.drawPath(handle, strokePaint);

    // Stroke — middle shelf line
    final shelf = Path();
    shelf.moveTo(22, 12);
    shelf.lineTo(12.3922, 13.9216);
    shelf.cubicTo(12.1333, 13.9733, 11.8667, 13.9733, 11.6078, 13.9216);
    shelf.lineTo(2, 12);
    canvas.drawPath(shelf, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_JobsIconPainter old) =>
      old.strokeColor != strokeColor || old.fillColor != fillColor;
}

// ── Alerts Icon ───────────────────────────────────────────────

class _AlertsIcon extends StatelessWidget {
  final Color strokeColor;
  final Color fillColor;
  final double width;
  final double height;
  const _AlertsIcon({
    required this.strokeColor,
    required this.fillColor,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _AlertsIconPainter(
              strokeColor: strokeColor, fillColor: fillColor),
        ),
      );
}

class _AlertsIconPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  const _AlertsIconPainter(
      {required this.strokeColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Bell body path
    final bell = Path();
    bell.moveTo(3.26176, 15.326);
    bell.cubicTo(3.13112, 15.4692, 3.04491, 15.6472, 3.01361, 15.8385);
    bell.cubicTo(2.98231, 16.0298, 3.00728, 16.226, 3.08546, 16.4034);
    bell.cubicTo(3.16365, 16.5807, 3.29169, 16.7316, 3.45401, 16.8375);
    bell.cubicTo(3.61633, 16.9434, 3.80594, 16.9999, 3.99976, 17);
    bell.lineTo(19.9998, 17);
    bell.cubicTo(20.1936, 17.0001, 20.3832, 16.9438, 20.5456, 16.8381);
    bell.cubicTo(20.708, 16.7324, 20.8363, 16.5817, 20.9146, 16.4045);
    bell.cubicTo(20.993, 16.2273, 21.0182, 16.0311, 20.9872, 15.8398);
    bell.cubicTo(20.9561, 15.6485, 20.8702, 15.4703, 20.7398, 15.327);
    bell.cubicTo(19.4098, 13.956, 17.9998, 12.499, 17.9998, 8);
    bell.cubicTo(17.9998, 6.4087, 17.3676, 4.88258, 16.2424, 3.75736);
    bell.cubicTo(15.1172, 2.63214, 13.5911, 2, 11.9998, 2);
    bell.cubicTo(10.4085, 2, 8.88234, 2.63214, 7.75712, 3.75736);
    bell.cubicTo(6.6319, 4.88258, 5.99976, 6.4087, 5.99976, 8);
    bell.cubicTo(5.99976, 12.499, 4.58876, 13.956, 3.26176, 15.326);
    bell.close();

    canvas.drawPath(bell, fillPaint);
    canvas.drawPath(bell, strokePaint);

    // Stroke — clapper
    final clapper = Path();
    clapper.moveTo(10.2681, 21);
    clapper.cubicTo(10.4436, 21.304, 10.6961, 21.5565, 11.0001, 21.732);
    clapper.cubicTo(11.3041, 21.9075, 11.649, 21.9999, 12.0001, 21.9999);
    clapper.cubicTo(12.3511, 21.9999, 12.696, 21.9075, 13, 21.732);
    clapper.cubicTo(13.3041, 21.5565, 13.5565, 21.304, 13.7321, 21);
    canvas.drawPath(clapper, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlertsIconPainter old) =>
      old.strokeColor != strokeColor || old.fillColor != fillColor;
}

// ── Profile Icon ─────────────────────────────────────────────

class _ProfileIcon extends StatelessWidget {
  final Color strokeColor;
  final Color fillColor;
  final double width;
  final double height;
  const _ProfileIcon({
    required this.strokeColor,
    required this.fillColor,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _ProfileIconPainter(
              strokeColor: strokeColor, fillColor: fillColor),
        ),
      );
}

class _ProfileIconPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  const _ProfileIconPainter(
      {required this.strokeColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Head circle
    final head = Path();
    head.moveTo(13.5714, 5.70588);
    head.cubicTo(13.5714, 8.30487, 11.5247, 10.4118, 9, 10.4118);
    head.cubicTo(6.47527, 10.4118, 4.42857, 8.30487, 4.42857, 5.70588);
    head.cubicTo(4.42857, 3.10689, 6.47527, 1, 9, 1);
    head.cubicTo(11.5247, 1, 13.5714, 3.10689, 13.5714, 5.70588);
    head.close();
    canvas.drawPath(head, fillPaint);
    canvas.drawPath(head, strokePaint);

    // Shoulders (stroke only)
    final shoulders = Path();
    shoulders.moveTo(1, 21);
    shoulders.lineTo(1, 19.8235);
    shoulders.cubicTo(1, 16.5748, 3.55838, 13.9412, 6.71429, 13.9412);
    shoulders.lineTo(11.2857, 13.9412);
    shoulders.cubicTo(14.4416, 13.9412, 17, 16.5748, 17, 19.8235);
    shoulders.lineTo(17, 21);
    canvas.drawPath(shoulders, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProfileIconPainter old) =>
      old.strokeColor != strokeColor || old.fillColor != fillColor;
}
