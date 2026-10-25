import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../saas/models/org_branding.dart';
import '../../saas/offline/branding_local_cache.dart';
import '../../saas/offline/connectivity_monitor.dart';
import '../../saas/offline/offline_controller.dart';
import '../../saas/offline/offline_local_store.dart';
import '../../saas/offline/offline_sync_service.dart';
import '../../saas/offline/offline_sync_status.dart';
import '../../saas/providers/auth_controller.dart';
import '../../saas/providers/quote_editor_controller.dart';
import '../../saas/services/branding_storage_service.dart';
import '../../ui/layout/responsive.dart';
import '../../widgets/simple_color_dialog.dart';
import '../account/company_identity_screen.dart';
import '../account/pricing_screen.dart';

/// Logo y colores de la cotización (usa identidad de empresa + override local).
class QuoteBrandingSection extends StatefulWidget {
  const QuoteBrandingSection({super.key, required this.controller});

  final QuoteEditorController controller;

  @override
  State<QuoteBrandingSection> createState() => _QuoteBrandingSectionState();
}

class _QuoteBrandingSectionState extends State<QuoteBrandingSection> {
  bool _uploading = false;
  Uint8List? _previewBytes;

  static final ButtonStyle _tonalCompact = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
  );

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant QuoteBrandingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.controller.quote.logoPath;
    final prev = oldWidget.controller.quote.logoPath;
    if (next != prev) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final path = widget.controller.quote.logoPath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _previewBytes = null);
      return;
    }
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final bytes = await BrandingStorageService.instance.loadLogoBytes(
      path,
      organizationId: auth.organizationId,
      uid: auth.sessionUid,
    );
    if (!mounted) return;
    setState(() => _previewBytes = bytes);
  }

  Map<String, String> _colorsOf(String? json) {
    const defaults = {
      'primary': '#1A1A2E',
      'secondary': '#2D6A4F',
      'accent': '#40916C',
      'success': '#D8F3DC',
      'error': '#FFE5E5',
    };
    if (json == null || json.isEmpty) return Map.from(defaults);
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return {
        for (final e in defaults.entries)
          e.key: (map[e.key] as String?) ?? e.value,
      };
    } catch (_) {
      return Map.from(defaults);
    }
  }

  Future<void> _ensurePro() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Branding personalizado disponible en Pro o durante la prueba.',
        ),
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PricingScreen()),
    );
  }

  Future<void> _pickLogo() async {
    if (_uploading) return;
    final auth = context.read<AuthController>();
    if (!auth.canCustomBranding) {
      await _ensurePro();
      return;
    }
    final orgId = auth.organizationId;
    final uid = auth.sessionUid;
    if (orgId == null || uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para subir el logo.'),
        ),
      );
      return;
    }

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir la galería: '
            '${'$e'.replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return;
    }
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      BrandingStorageService.instance.validateLogoBytes(
        bytes,
        fileName: picked.name,
      );

      final online = await ConnectivityMonitor.instance.probeFirebase();
      String? logoRef;
      var savedOffline = false;

      if (online) {
        try {
          final uploaded = await BrandingStorageService.instance.uploadOrgLogo(
            orgId: orgId,
            uid: uid,
            bytes: bytes,
            fileName: picked.name,
          );
          logoRef = uploaded.url;
          await BrandingLocalCache.instance.saveLogoBytes(
            organizationId: orgId,
            uid: uid,
            bytes: bytes,
            branding: OrgBranding(
              logoUrl: uploaded.url,
              logoStoragePath: uploaded.storagePath,
            ),
            pendingUpload: false,
          );
        } catch (e) {
          debugPrint('uploadOrgLogo online falló, guardando local: $e');
        }
      }

      // Sin red o fallo de Storage: guardar archivo local y encolar subida.
      if (logoRef == null || logoRef.isEmpty) {
        final localPath = await BrandingLocalCache.instance.saveQuoteLogoBytes(
          organizationId: orgId,
          quoteId: widget.controller.quote.id,
          bytes: bytes,
        );
        if (localPath == null || localPath.isEmpty) {
          throw Exception(
            'No se pudo guardar el logo en este dispositivo. '
            'Revisa el espacio de almacenamiento e inténtalo de nuevo.',
          );
        }
        logoRef = localPath;
        savedOffline = true;

        // Encola subida del archivo de esta cotización.
        // logoLocalPath es temporal en dispositivo; la sync lo cambia a URL remota.
        await OfflineLocalStore.instance.enqueue(
          organizationId: orgId,
          uid: uid,
          entityType: OfflineEntityType.brandingLogo,
          entityId: 'quote:${widget.controller.quote.id}',
          operation: OfflineOperation.uploadFile,
          payload: {
            'logoLocalPath': localPath,
            'quoteId': widget.controller.quote.id,
          },
          idempotencyKey: OfflineSyncService.idempotencyKey(
            type: OfflineEntityType.brandingLogo,
            entityId: 'quote:${widget.controller.quote.id}',
            op: OfflineOperation.uploadFile,
            revision: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        await OfflineController.instance.refresh();
      }

      // Override solo de esta cotización (no reaplicar identidad de empresa).
      widget.controller.setLogoPath(logoRef);
      if (mounted) {
        setState(() => _previewBytes = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedOffline
                  ? 'Logo de esta cotización guardado en el dispositivo. '
                        'El de la empresa no se modifica.'
                  : 'Logo aplicado solo a esta cotización. '
                        'Usa Identidad visual si quieres cambiar el de la empresa.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              BrandingStorageService.describeUploadError(e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      } else {
        _uploading = false;
      }
    }
  }

  Future<void> _clearLogo() async {
    final auth = context.read<AuthController>();
    if (!auth.canCustomBranding) {
      await _ensurePro();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar logo de esta cotización'),
        content: const Text(
          'Solo se quita de esta cotización. '
          'El logo de la empresa en Identidad visual no se elimina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.controller.setLogoPath(null);
    setState(() => _previewBytes = null);
  }

  Future<void> _applyOrgIdentity() async {
    final auth = context.read<AuthController>();
    if (!auth.canCustomBranding) {
      await _ensurePro();
      return;
    }
    await widget.controller.applyOrganizationBranding(
      organization: auth.organization,
    );
    await _loadPreview();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identidad de la empresa aplicada')),
      );
    }
  }

  Future<void> _editColor(String key) async {
    final auth = context.read<AuthController>();
    if (!auth.canCustomBranding) {
      await _ensurePro();
      return;
    }
    final colors = _colorsOf(widget.controller.quote.colorsJson);
    final current = colors[key] ?? '#1A1A2E';
    final hexOnly = current.replaceAll('#', '');
    final initial = hexOnly.length >= 6
        ? hexOnly.substring(hexOnly.length - 6)
        : hexOnly;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleColorDialog(initial),
    );
    if (picked == null) return;
    final normalized = picked.startsWith('#') ? picked : '#$picked';
    final rgb = normalized.length >= 7
        ? '#${normalized.substring(normalized.length - 6)}'
        : normalized;
    colors[key] = rgb.toUpperCase();
    widget.controller.setColorsJson(jsonEncode(colors));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final q = widget.controller.quote;
    final colors = _colorsOf(q.colorsJson);
    final locked = !auth.canCustomBranding;
    final layout = OrgBranding.fromQuoteLegacy(
      logoPath: q.logoPath,
      colorsJson: q.colorsJson,
      legacy: q.legacyFields,
    );
    final hasLogo = q.logoPath != null && q.logoPath!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Identidad visual',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Pro'),
                visualDensity: VisualDensity.compact,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          locked
              ? 'Disponible con plan Pro o prueba activa.'
              : 'Logo y colores del PDF. Configura el predeterminado en Mi cuenta.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          height: 96,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: !hasLogo
              ? Center(
                  child: Text(
                    'Aún no hay logotipo en esta cotización.\n'
                    'Puedes cargarlo desde la galería aunque no haya internet.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                )
              : _previewBytes == null
              ? Center(
                  child: Text(
                    'Logo asignado, pero la vista previa no está disponible '
                    'sin el archivo local. Vuelve a cargarlo desde la galería.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                )
              : Align(
                  alignment: switch (layout.logoAlignment) {
                    LogoAlignment.left => Alignment.centerLeft,
                    LogoAlignment.center => Alignment.center,
                    LogoAlignment.right => Alignment.centerRight,
                  },
                  child: Image.memory(
                    _previewBytes!,
                    height: layout.logoSizePt.clamp(24, 72),
                    fit: BoxFit.contain,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              style: _tonalCompact,
              onPressed: _uploading ? null : _pickLogo,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(hasLogo ? 'Cambiar logotipo' : 'Subir logotipo'),
            ),
            if (hasLogo)
              TextButton(
                onPressed: _uploading ? null : _clearLogo,
                child: const Text('Eliminar logotipo'),
              ),
            TextButton(
              onPressed: locked
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanyIdentityScreen(),
                        ),
                      );
                      // No reaplicar automáticamente: el usuario puede haber
                      // personalizado el logo solo de esta cotización.
                      if (mounted) await _loadPreview();
                    },
              child: const Text('Configurar empresa'),
            ),
            TextButton(
              onPressed: locked ? null : _applyOrgIdentity,
              child: const Text('Usar logo de empresa'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Tamaño en PDF', style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: layout.logoSizePt,
          min: OrgBranding.minLogoSizePt,
          max: OrgBranding.maxLogoSizePt,
          divisions: 12,
          label: '${layout.logoSizePt.round()} pt',
          onChanged: locked
              ? null
              : (v) => widget.controller.applyLogoLayout(logoSizePt: v),
        ),
        SegmentedButton<LogoAlignment>(
          segments: [
            for (final a in LogoAlignment.values)
              ButtonSegment(value: a, label: Text(a.label)),
          ],
          selected: {layout.logoAlignment},
          onSelectionChanged: locked
              ? null
              : (s) => widget.controller.applyLogoLayout(alignment: s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Marca de agua (esta cotización)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            layout.watermarkEnabled ? 'Activada' : 'Desactivada',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          value: layout.watermarkEnabled,
          onChanged: locked
              ? null
              : (v) {
                  if (v && !hasLogo) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sube o aplica el logo de la empresa primero.',
                        ),
                      ),
                    );
                    return;
                  }
                  widget.controller.applyWatermarkSettings(enabled: v);
                },
        ),
        Text(
          'Opacidad ${layout.watermarkOpacityPct}%',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: layout.watermarkOpacityPct.toDouble(),
          min: OrgBranding.minWatermarkOpacityPct.toDouble(),
          max: OrgBranding.maxWatermarkOpacityPct.toDouble(),
          divisions: OrgBranding.maxWatermarkOpacityPct -
              OrgBranding.minWatermarkOpacityPct,
          label: '${layout.watermarkOpacityPct}%',
          onChanged: locked || !layout.watermarkEnabled
              ? null
              : (v) => widget.controller.applyWatermarkSettings(
                  opacityPct: v.round(),
                ),
        ),
        SegmentedButton<WatermarkSize>(
          segments: [
            for (final s in WatermarkSize.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {layout.watermarkSize},
          onSelectionChanged: locked || !layout.watermarkEnabled
              ? null
              : (s) =>
                    widget.controller.applyWatermarkSettings(size: s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<WatermarkPosition>(
          key: ValueKey('wm-${layout.watermarkPosition.id}'),
          initialValue: layout.watermarkPosition,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Posición marca de agua',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final p in WatermarkPosition.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: locked || !layout.watermarkEnabled
              ? null
              : (p) {
                  if (p != null) {
                    widget.controller.applyWatermarkSettings(position: p);
                  }
                },
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in colors.entries)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: _parseColor(e.value),
                  radius: 8,
                ),
                label: Text(e.key),
                onPressed: () => _editColor(e.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      final v = h.length == 6 ? 'FF$h' : h;
      return Color(int.parse(v, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
