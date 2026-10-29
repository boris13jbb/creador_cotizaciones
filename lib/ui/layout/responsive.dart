import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

export '../tokens/app_colors.dart';
export '../tokens/app_spacing.dart';

/// Clase de ventana según el ancho disponible.
enum AppWindowSize { compact, medium, expanded }

/// Helpers de layout responsive.
///
/// Cambios de navegación “significativos” (drawer, rail colapsable, destinos
/// extra) se activan solo en Web vía [isWebAdaptive]. Los breakpoints de
/// ancho siguen siendo útiles en todas las plataformas para overflow/padding.
abstract final class Responsive {
  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double heightOf(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool get isWebAdaptive => kIsWeb;

  static AppWindowSize windowSizeOf(BuildContext context) {
    final w = widthOf(context);
    if (w >= AppBreakpoints.expanded) return AppWindowSize.expanded;
    if (w >= AppBreakpoints.medium) return AppWindowSize.medium;
    return AppWindowSize.compact;
  }

  static bool isCompact(BuildContext context) =>
      widthOf(context) < AppBreakpoints.medium;

  static bool isMedium(BuildContext context) {
    final w = widthOf(context);
    return w >= AppBreakpoints.medium && w < AppBreakpoints.expanded;
  }

  static bool isExpanded(BuildContext context) =>
      widthOf(context) >= AppBreakpoints.expanded;

  /// NavigationRail permanente.
  /// Web: ≥ 1024. Nativo: ≥ 840 (comportamiento previo).
  static bool useNavigationRail(BuildContext context) {
    final w = widthOf(context);
    if (isWebAdaptive) return w >= AppBreakpoints.expanded;
    return w >= AppBreakpoints.nativeRail;
  }

  /// En Web tablet: menú lateral tipo Drawer en lugar de bottom bar densa.
  static bool useWebNavigationDrawer(BuildContext context) =>
      isWebAdaptive && isMedium(context);

  /// Bottom NavigationBar (móvil; también tablet nativo &lt; nativeRail).
  static bool useBottomNavigation(BuildContext context) =>
      !useNavigationRail(context) && !useWebNavigationDrawer(context);

  /// Padding de página según ancho.
  static EdgeInsets pagePadding(BuildContext context) {
    final w = widthOf(context);
    if (w >= AppBreakpoints.expanded) return AppSpacing.pageWide;
    if (w >= AppBreakpoints.medium) {
      return const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 4,
        vertical: AppSpacing.md,
      );
    }
    return AppSpacing.pageCompact;
  }

  /// Ancho máximo de contenido según el tipo de página.
  static double contentMaxWidth({
    bool form = false,
    double? override,
  }) {
    if (override != null) return override;
    return form ? AppBreakpoints.formMax : AppBreakpoints.contentMax;
  }

  /// Columnas útiles para grids de acciones / KPIs.
  static int actionColumns(BuildContext context) {
    final w = widthOf(context);
    if (w < 360) return 1;
    if (w < AppBreakpoints.medium) return 2;
    if (w < AppBreakpoints.expanded) return 3;
    return 4;
  }

  static int kpiColumns(BuildContext context) {
    final w = widthOf(context);
    if (w < 400) return 1;
    if (w < AppBreakpoints.medium) return 2;
    // 3 columnas en tablet/desktop evita recortes con rail + padding.
    return 3;
  }
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

  /// Variante para formularios / ajustes (ancho útil más estrecho).
  const ContentConstraint.form({
    super.key,
    required this.child,
    this.padding,
  }) : maxWidth = AppBreakpoints.formMax;

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

/// Diálogo que no desborda el viewport (móvil / teclado).
Future<T?> showAdaptiveAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final insets = MediaQuery.viewInsetsOf(ctx);
      final maxH = (size.height - insets.bottom) * 0.9;
      final maxW = size.width < AppBreakpoints.medium
          ? size.width - 32
          : AppBreakpoints.dialogMax;
      return Dialog(
        insetPadding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: 16 + insets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: builder(ctx),
        ),
      );
    },
  );
}

/// Envuelve un [AlertDialog] con scroll y ancho acotado al viewport.
class AdaptiveAlertDialog extends StatelessWidget {
  const AdaptiveAlertDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.scrollable = true,
  });

  final Widget? title;
  final Widget content;
  final List<Widget>? actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width < AppBreakpoints.medium
        ? size.width - 48
        : AppBreakpoints.dialogMax;
    final body = scrollable
        ? SingleChildScrollView(child: content)
        : content;
    return AlertDialog(
      title: title,
      content: SizedBox(width: maxW, child: body),
      actions: actions,
    );
  }
}

/// Barra inferior de acciones que apila en compacto y alinea en fila en ancho.
class AdaptiveActionBar extends StatelessWidget {
  const AdaptiveActionBar({
    super.key,
    required this.leading,
    required this.trailing,
    this.center,
    this.elevation = 6,
  });

  final List<Widget> leading;
  final List<Widget> trailing;
  final Widget? center;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
    );

    final child = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (center != null) ...[
                center!,
                const SizedBox(height: AppSpacing.xs),
              ],
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  ...leading,
                  ...trailing,
                ],
              ),
            ],
          )
        : Row(
            children: [
              ...leading,
              if (center != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: center!),
              ] else
                const Spacer(),
              const SizedBox(width: AppSpacing.sm),
              ...trailing.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: w,
                ),
              ),
            ],
          );

    return Material(
      elevation: elevation,
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Grid responsivo simple (acciones, KPIs).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    required this.columns,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
    this.childAspectRatio,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;

  @override
  Widget build(BuildContext context) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
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
        final cols = columns.clamp(1, children.length);
        final totalSpacing = spacing * (cols - 1);
        // Floor evita que N columnas + gaps superen el ancho por redondeo.
        final itemW = ((maxW - totalSpacing) / cols).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemW > 0 ? itemW : maxW,
                child: childAspectRatio == null
                    ? child
                    : AspectRatio(
                        aspectRatio: childAspectRatio!,
                        child: child,
                      ),
              ),
          ],
        );
      },
    );
  }
}
