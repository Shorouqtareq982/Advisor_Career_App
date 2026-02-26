// =============================================================
// PROFESSIONAL FLUTTER RESPONSIVE SYSTEM (PRODUCTION READY)
// Plug & Play
// Supports: Mobile, Tablet, Desktop, Ultra-wide
// =============================================================

import 'package:flutter/material.dart';

// =============================================================
// BREAKPOINTS
// =============================================================

class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

// =============================================================
// DEVICE TYPE
// =============================================================

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

// =============================================================
// RESPONSIVE HELPER
// =============================================================

class Responsive {
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.mobile) {
      return DeviceType.mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;
}

// =============================================================
// RESPONSIVE VALUE
// =============================================================

class ResponsiveValue<T> {
  final T mobile;
  final T tablet;
  final T desktop;

  ResponsiveValue({
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  T get(BuildContext context) {
    switch (Responsive.getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }
}

// =============================================================
// RESPONSIVE SCAFFOLD
// =============================================================

class ResponsiveScaffold extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveScaffold({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    switch (Responsive.getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;

      case DeviceType.tablet:
        return tablet;

      case DeviceType.desktop:
        return desktop;
    }
  }
}

// =============================================================
// RESPONSIVE CONTAINER
// Keeps content centered and constrained on desktop
// =============================================================

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// =============================================================
// RESPONSIVE GRID
// =============================================================

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;

  const ResponsiveGrid({
    super.key,
    required this.children,
  });

  int _getCrossAxisCount(BuildContext context) {
    if (Responsive.isMobile(context)) return 1;
    if (Responsive.isTablet(context)) return 2;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: _getCrossAxisCount(context),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: children,
    );
  }
}

// =============================================================
// RESPONSIVE TEXT
// =============================================================

class ResponsiveText extends StatelessWidget {
  final String text;

  const ResponsiveText(this.text, {super.key});

  double _getFontSize(BuildContext context) {
    if (Responsive.isMobile(context)) return 16;
    if (Responsive.isTablet(context)) return 20;
    return 24;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: _getFontSize(context),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// =============================================================
// EXAMPLE SCREEN
// =============================================================

class ExampleResponsiveScreen extends StatelessWidget {
  const ExampleResponsiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      mobile: _MobileLayout(),
      tablet: _TabletLayout(),
      desktop: _DesktopLayout(),
    );
  }
}

// =============================================================
// MOBILE
// =============================================================

class _MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mobile")),
      body: const ResponsiveContainer(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ResponsiveText("Mobile Layout"),
        ),
      ),
    );
  }
}

// =============================================================
// TABLET
// =============================================================

class _TabletLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tablet")),
      body: const ResponsiveContainer(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: ResponsiveText("Tablet Layout"),
        ),
      ),
    );
  }
}

// =============================================================
// DESKTOP
// =============================================================

class _DesktopLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Desktop")),
      body: const ResponsiveContainer(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: ResponsiveText("Desktop Layout"),
        ),
      ),
    );
  }
}

// =============================================================
// HOW TO USE
// =============================================================

/*

1. Put this file in:

lib/core/responsive/responsive_system.dart


2. Use like this:

home: ExampleResponsiveScreen()


3. Or use ResponsiveValue:

padding: EdgeInsets.all(
  ResponsiveValue(
    mobile: 16,
    tablet: 24,
    desktop: 32,
  ).get(context),
)


4. Check device type:

if (Responsive.isDesktop(context)) {
  showSidebar();
}

*/

// =============================================================
// END
// =============================================================
