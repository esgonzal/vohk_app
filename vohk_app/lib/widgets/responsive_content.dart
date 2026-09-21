import 'package:flutter/material.dart';

/// Keeps phone layouts unchanged while preventing tablet content from
/// stretching across the entire display.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double breakpoint;

  const ResponsiveContent({super.key, required this.child, this.maxWidth = 960, this.breakpoint = 600});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) return child;
        return Center(
          child: SizedBox(width: constraints.maxWidth.clamp(0, maxWidth).toDouble(), height: constraints.maxHeight, child: child),
        );
      },
    );
  }
}

bool isTabletWidth(BuildContext context) => MediaQuery.sizeOf(context).width >= 600;

bool isWideTabletWidth(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;
