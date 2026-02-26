import 'package:flutter/material.dart';
import '../utils/responsive.dart';

extension ResponsiveExtension on BuildContext {
  // Quick access to screen dimensions
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  // Device type checks
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  //  Responsive size helpers
  double w(double designWidth) => Responsive.width(this, designWidth);
  double h(double designHeight) => Responsive.height(this, designHeight);
  double sp(double designFontSize) => Responsive.fontSize(this, designFontSize);
  double r(double designRadius) => Responsive.radius(this, designRadius);

  //  Icon and Logo helpers
  double icon(double designIconSize) => Responsive.icon(this, designIconSize);
  double logo(double designLogoSize) => Responsive.logo(this, designLogoSize);

  // Dynamic spacing
  double get lowValue => h(8);
  double get mediumValue => h(16);
  double get highValue => h(24);
  double get veryHighValue => h(32);

  // Dynamic padding/margin shortcuts
  EdgeInsets get lowPadding => EdgeInsets.all(lowValue);
  EdgeInsets get mediumPadding => EdgeInsets.all(mediumValue);
  EdgeInsets get highPadding => EdgeInsets.all(highValue);

  EdgeInsets get horizontalLowPadding =>
      EdgeInsets.symmetric(horizontal: lowValue);
  EdgeInsets get horizontalMediumPadding =>
      EdgeInsets.symmetric(horizontal: mediumValue);
  EdgeInsets get horizontalHighPadding =>
      EdgeInsets.symmetric(horizontal: highValue);

  EdgeInsets get verticalLowPadding => EdgeInsets.symmetric(vertical: lowValue);
  EdgeInsets get verticalMediumPadding =>
      EdgeInsets.symmetric(vertical: mediumValue);
  EdgeInsets get verticalHighPadding =>
      EdgeInsets.symmetric(vertical: highValue);

  // Dynamic SizedBox shortcuts
  Widget get lowSpace => SizedBox(height: lowValue);
  Widget get mediumSpace => SizedBox(height: mediumValue);
  Widget get highSpace => SizedBox(height: highValue);
  Widget get veryHighSpace => SizedBox(height: veryHighValue);

  Widget get lowWidthSpace => SizedBox(width: lowValue);
  Widget get mediumWidthSpace => SizedBox(width: mediumValue);
  Widget get highWidthSpace => SizedBox(width: highValue);

  //  White Container Height
  double get whiteContainerHeight {
    final baseHeight = screenHeight * 0.75;

    if (isDesktop) {
      return Responsive.clampSize(baseHeight, min: 600.0, max: 900.0);
    }
    if (isTablet) {
      return Responsive.clampSize(baseHeight, min: 500.0, max: 800.0);
    }
    return screenHeight - h(200);
  }

  double get whiteContainerTop {
    if (isDesktop) {
      final topValue = screenHeight * 0.25;
      return Responsive.clampSize(topValue, min: 200.0, max: 350.0);
    }
    if (isTablet) {
      final topValue = screenHeight * 0.22;
      return Responsive.clampSize(topValue, min: 180.0, max: 300.0);
    }
    return h(200);
  }

  BoxConstraints get contentConstraints => BoxConstraints(
        maxWidth: isDesktop
            ? 600
            : isTablet
                ? 500
                : double.infinity,
      );

  double get safeTopPadding => MediaQuery.of(this).padding.top;
  double get safeBottomPadding => MediaQuery.of(this).padding.bottom;
  double get safeLeftPadding => MediaQuery.of(this).padding.left;
  double get safeRightPadding => MediaQuery.of(this).padding.right;

  double get contentMaxWidth {
    if (isDesktop) return 600.0;
    if (isTablet) return 500.0;
    return screenWidth;
  }

  EdgeInsets get contentHorizontalPadding {
    if (isDesktop) return EdgeInsets.symmetric(horizontal: w(40));
    if (isTablet) return EdgeInsets.symmetric(horizontal: w(32));
    return EdgeInsets.symmetric(horizontal: w(24));
  }

  void printResponsiveInfo() {
    final info = Responsive.getScaleFactors(this);
    print('📱 Responsive Info:');
    print(
        '   Device Type: ${isMobile ? "Mobile" : isTablet ? "Tablet" : "Desktop"}');
    print(
        '   Screen: ${screenWidth.toStringAsFixed(0)}x${screenHeight.toStringAsFixed(0)}');
    print('   Width Scale: ${info['widthScale']?.toStringAsFixed(2)}');
    print('   Height Scale: ${info['heightScale']?.toStringAsFixed(2)}');
    print('   Combined Scale: ${info['combinedScale']?.toStringAsFixed(2)}');
    print('   Container Height: ${whiteContainerHeight.toStringAsFixed(0)}');
    print('   Container Top: ${whiteContainerTop.toStringAsFixed(0)}');
  }
}
