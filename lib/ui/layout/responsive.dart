import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

export '../tokens/app_colors.dart';
export '../tokens/app_spacing.dart';

/// Helpers de layout responsive.
abstract final class Responsive {
  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) =>
      widthOf(context) < AppBreakpoints.medium;

  static bool isExpanded(BuildContext context) =>
      widthOf(context) >= AppBreakpoints.expanded;

  static bool useNavigationRail(BuildContext context) => isExpanded(context);
}

/// Centra el contenido y limita el ancho en escritorio.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMax,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}
