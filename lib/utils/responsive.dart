import 'package:flutter/material.dart';

/// Responsive layout breakpoints matching the target device classes:
/// - Mobile: width < 600px
/// - Tablet: 600px <= width <= 1024px
/// - Desktop: width > 1024px
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  static const double mobile = 600.0;
  static const double tablet = 1024.0;

  static bool isMobileWidth(double width) => width < mobile;
  static bool isTabletWidth(double width) =>
      width >= mobile && width <= tablet;
  static bool isDesktopWidth(double width) => width > tablet;
  static bool isCompactWidth(double width) => width < 768.0;

  static bool isMobile(BuildContext context) =>
      isMobileWidth(MediaQuery.sizeOf(context).width);

  static bool isTablet(BuildContext context) =>
      isTabletWidth(MediaQuery.sizeOf(context).width);

  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(MediaQuery.sizeOf(context).width);

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < ResponsiveBreakpoints.mobile) return mobile;
    if (width <= ResponsiveBreakpoints.tablet) return tablet ?? desktop;
    return desktop;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    EdgeInsets desktop = const EdgeInsets.all(24),
    EdgeInsets? tablet,
    EdgeInsets mobile = const EdgeInsets.all(14),
  }) {
    return value(
      context,
      mobile: mobile,
      tablet: tablet ?? const EdgeInsets.all(20),
      desktop: desktop,
    );
  }

  static EdgeInsets dialogInsetPadding(BuildContext context) {
    return isMobile(context)
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
  }

  static double dialogMaxWidth(
    BuildContext context, {
    double desktopMaxWidth = 520,
  }) {
    final width = screenWidth(context);
    if (width < mobile) return width - 24;
    return desktopMaxWidth;
  }
}

/// Lays out children horizontally inside a [Row] when available width meets
/// [breakpoint], and stacks them vertically in a [Column] below it.
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  final double horizontalSpacing;
  final double verticalSpacing;
  final bool expandChildrenInRow;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment rowMainAxisAlignment;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.breakpoint = ResponsiveBreakpoints.mobile,
    this.horizontalSpacing = 12,
    this.verticalSpacing = 12,
    this.expandChildrenInRow = true,
    this.rowCrossAxisAlignment = CrossAxisAlignment.start,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumn = constraints.maxWidth < breakpoint;
        if (useColumn) {
          final columnChildren = <Widget>[];
          for (var i = 0; i < children.length; i++) {
            if (i > 0) columnChildren.add(SizedBox(height: verticalSpacing));
            columnChildren.add(children[i]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: columnChildren,
          );
        }

        final rowChildren = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          if (i > 0) rowChildren.add(SizedBox(width: horizontalSpacing));
          rowChildren.add(
            expandChildrenInRow ? Expanded(child: children[i]) : children[i],
          );
        }
        return Row(
          crossAxisAlignment: rowCrossAxisAlignment,
          mainAxisAlignment: rowMainAxisAlignment,
          children: rowChildren,
        );
      },
    );
  }
}

/// Renders a multi-column grid whose tiles size naturally to their intrinsic
/// height rather than forcing a rigid `childAspectRatio` that overflows on
/// narrow mobile or tablet screens.
class ResponsiveWrapGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double mobileBreakpoint;
  final double desktopBreakpoint;
  final double spacing;
  final double runSpacing;

  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
    this.mobileBreakpoint = ResponsiveBreakpoints.mobile,
    this.desktopBreakpoint = 1100,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int columns;
        if (width < mobileBreakpoint) {
          columns = mobileColumns;
        } else if (width < desktopBreakpoint) {
          columns = tabletColumns;
        } else {
          columns = desktopColumns;
        }

        if (columns <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final rowItems = <Widget>[];
          for (var col = 0; col < columns; col++) {
            if (col > 0) rowItems.add(SizedBox(width: spacing));
            final idx = i + col;
            if (idx < children.length) {
              rowItems.add(Expanded(child: children[idx]));
            } else {
              rowItems.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          if (i > 0) rows.add(SizedBox(height: runSpacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowItems,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
