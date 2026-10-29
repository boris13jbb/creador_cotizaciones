import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/enum_l10n.dart';
import '../../l10n/l10n_ext.dart';
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
import '../../saas/services/quote_logo_resolver.dart';
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
  bool _previewLoading = false;
  Uint8List? _previewBytes;
  String? _previewSourceKey;

  static final ButtonStyle _tonalCompact = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
  );

  String _sourceKey(String? quoteLogo, OrgBranding? org) {
    return '${quoteLogo ?? ''}|${org?.logoUrl ?? ''}|${org?.logoStoragePath ?? ''}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
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
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final orgBranding = auth.organization?.visualIdentity;
    final quoteLogo = widget.controller.quote.logoPath;
    final key = _sourceKey(quoteLogo, orgBranding);
    final resolved = QuoteLogoResolver.resolveLogoPath(
      quoteLogoPath: quoteLogo,
      orgBranding: orgBranding,
    );

    setState(() {
      _previewLoading = true;
      _previewSourceKey = key;
      if (resolved == null || resolved.isEmpty) {
        _previewBytes = null;
      }
    });

    if (resolved == null || resolved.isEmpty) {
      if (mounted) setState(() => _previewLoading = false);
      return;
    }

    final bytes = await BrandingStorageService.instance.loadLogoBytes(
      resolved,
      organizationId: auth.organizationId,
      uid: auth.sessionUid,
      cacheRemoteAsOrgLogo: !QuoteLogoResolver.hasCustomLogo(
        quoteLogo,
        orgBranding: orgBranding,
      ),
    );
    if (!mounted) return;
    // Evitar aplicar resultado obsoleto si cambió el origen mientras cargaba.
    if (_previewSourceKey != key) return;
    setState(() {
      _previewBytes = bytes;
      _previewLoading = false;
    });
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
      SnackBar(content: Text(context.l10n.brandingProRequired)),
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
        SnackBar(content: Text(context.l10n.mustSignIn)),
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
        SnackBar(content: Text(context.l10n.imagePickerFailed)),
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

      final quoteId = widget.controller.quote.id;
      final online = await ConnectivityMonitor.instance.probeFirebase();
      String? logoRef;
      var savedOffline = false;

      // Siempre conservar copia local por cotización (no tocar logo.bin de empresa).
      final localPath = await BrandingLocalCache.instance.saveQuoteLogoBytes(
        organizationId: orgId,
        quoteId: quoteId,
        bytes: bytes,
      );

      if (online) {
        try {
          final uploaded = await BrandingStorageService.instance
              .uploadQuoteLogo(
                orgId: orgId,
                quoteId: quoteId,
                uid: uid,
                bytes: bytes,
                fileName: picked.name,
              );
          logoRef = uploaded.url;
        } catch (e) {
          debugPrint('uploadQuoteLogo online falló, guardando local: $e');
        }
      }

      // Sin red o fallo de Storage: ruta local + cola (solo plataformas con SQLite).
      if (logoRef == null || logoRef.isEmpty) {
        if (!OfflineLocalStore.isSupported ||
            localPath == null ||
            localPath.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.quoteLogoLocalSaveFailed)),
            );
          }
          return;
        }
        logoRef = localPath;
        savedOffline = true;

        await OfflineLocalStore.instance.enqueue(
          organizationId: orgId,
          uid: uid,
          entityType: OfflineEntityType.brandingLogo,
          entityId: 'quote:$quoteId',
          operation: OfflineOperation.uploadFile,
          payload: {'logoLocalPath': localPath, 'quoteId': quoteId},
          idempotencyKey: OfflineSyncService.idempotencyKey(
            type: OfflineEntityType.brandingLogo,
            entityId: 'quote:$quoteId',
            op: OfflineOperation.uploadFile,
            revision: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        await OfflineController.instance.refresh();
      }

      // Override solo de esta cotización (no toca Identidad visual).
      widget.controller.setLogoPath(logoRef);
      if (mounted) {
        setState(() => _previewBytes = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedOffline
                  ? context.l10n.quoteLogoSavedLocal
                  : context.l10n.quoteLogoAppliedQuoteOnly,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              BrandingStorageService.describeUploadError(e, context.l10n),
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
      builder: (ctx) {
        final d = ctx.l10n;
        return AlertDialog(
          title: Text(d.quoteLogoRemoveTitle),
          content: Text(d.quoteLogoRemoveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(d.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(d.removeAction),
            ),
          ],
        );
      },
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
        SnackBar(content: Text(context.l10n.quoteLogoOrgIdentityApplied)),
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
    final l10n = context.l10n;
    final auth = context.watch<AuthController>();
    final q = widget.controller.quote;
    final colors = _colorsOf(q.colorsJson);
    final locked = !auth.canCustomBranding;
    final orgBranding = auth.organization?.visualIdentity;
    final layout = OrgBranding.fromQuoteLegacy(
      logoPath: q.logoPath,
      colorsJson: q.colorsJson,
      legacy: q.legacyFields,
    );
    final hasCustomLogo = QuoteLogoResolver.hasCustomLogo(
      q.logoPath,
      orgBranding: orgBranding,
    );
    final resolvedPath = QuoteLogoResolver.resolveLogoPath(
      quoteLogoPath: q.logoPath,
      orgBranding: orgBranding,
    );
    final hasEffectiveLogo =
        resolvedPath != null && resolvedPath.trim().isNotEmpty;
    final sourceKey = _sourceKey(q.logoPath, orgBranding);
    if (sourceKey != _previewSourceKey && !_previewLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPreview();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.visualIdentity,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(l10n.proBadge),
                visualDensity: VisualDensity.compact,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          locked ? l10n.visualIdentityPro : l10n.visualIdentityOk,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (hasEffectiveLogo) ...[
          const SizedBox(height: AppSpacing.xs),
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              hasCustomLogo ? Icons.image_outlined : Icons.business_outlined,
              size: 16,
            ),
            label: Text(
              hasCustomLogo ? l10n.quoteLogoCustom : l10n.quoteLogoCompany,
            ),
          ),
        ],
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
          child: _previewLoading
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : !hasEffectiveLogo
              ? Center(
                  child: Text(
                    l10n.quoteLogoEmptyHint,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                )
              : _previewBytes == null
              ? Center(
                  child: Text(
                    hasCustomLogo
                        ? l10n.quoteLogoPreviewCustomFailed
                        : l10n.quoteLogoPreviewCompanyFailed,
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
              label: Text(
                hasCustomLogo ? l10n.changeLogo : l10n.uploadLogo,
              ),
            ),
            if (hasCustomLogo)
              TextButton(
                onPressed: _uploading ? null : _clearLogo,
                child: Text(l10n.quoteLogoRemoveCustomization),
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
                      // Tras cambiar Identidad visual, refrescar herencia.
                      if (mounted) await _loadPreview();
                    },
              child: Text(l10n.quoteLogoConfigureCompany),
            ),
            if (hasCustomLogo)
              TextButton(
                onPressed: locked ? null : _applyOrgIdentity,
                child: Text(l10n.quoteLogoUseCompany),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.pdfSizeLabel, style: Theme.of(context).textTheme.labelLarge),
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
              ButtonSegment(value: a, label: Text(a.l10nLabel(l10n))),
          ],
          selected: {layout.logoAlignment},
          onSelectionChanged: locked
              ? null
              : (s) => widget.controller.applyLogoLayout(alignment: s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.watermarkThisQuote,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            layout.watermarkEnabled ? l10n.watermarkOn : l10n.watermarkOff,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          value: layout.watermarkEnabled,
          onChanged: locked
              ? null
              : (v) {
                  if (v && !hasEffectiveLogo) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.watermarkNeedCompanyOrQuoteLogo),
                      ),
                    );
                    return;
                  }
                  widget.controller.applyWatermarkSettings(enabled: v);
                },
        ),
        Text(
          l10n.watermarkOpacity(layout.watermarkOpacityPct),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: layout.watermarkOpacityPct.toDouble(),
          min: OrgBranding.minWatermarkOpacityPct.toDouble(),
          max: OrgBranding.maxWatermarkOpacityPct.toDouble(),
          divisions:
              OrgBranding.maxWatermarkOpacityPct -
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
              ButtonSegment(value: s, label: Text(s.l10nLabel(l10n))),
          ],
          selected: {layout.watermarkSize},
          onSelectionChanged: locked || !layout.watermarkEnabled
              ? null
              : (s) => widget.controller.applyWatermarkSettings(size: s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<WatermarkPosition>(
          key: ValueKey('wm-${layout.watermarkPosition.id}'),
          initialValue: layout.watermarkPosition,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.watermarkPositionLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final p in WatermarkPosition.values)
              DropdownMenuItem(
                value: p,
                child: Text(p.l10nLabel(l10n)),
              ),
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
