import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/auth_error_l10n.dart';
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
import '../../saas/services/branding_storage_service.dart';
import '../../saas/services/organization_service.dart';
import '../../ui/layout/responsive.dart';
import '../../widgets/simple_color_dialog.dart';
import 'pricing_screen.dart';

/// Configuración de identidad visual de la empresa (logo + layout + colores).
class CompanyIdentityScreen extends StatefulWidget {
  const CompanyIdentityScreen({super.key});

  @override
  State<CompanyIdentityScreen> createState() => _CompanyIdentityScreenState();
}

class _CompanyIdentityScreenState extends State<CompanyIdentityScreen> {
  static final _tonalCompact = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
  );

  OrgBranding _draft = const OrgBranding();
  OrgBranding _saved = const OrgBranding();
  Uint8List? _previewBytes;
  bool _loading = true;
  bool _uploading = false;
  bool _saving = false;
  String? _error;
  bool _canManage = false;
  final _uploadGate = LogoUploadGate();

  bool get _dirty {
    return _draft.logoUrl != _saved.logoUrl ||
        _draft.logoStoragePath != _saved.logoStoragePath ||
        _draft.colorsJson != _saved.colorsJson ||
        _draft.logoSizePt != _saved.logoSizePt ||
        _draft.logoAlignment != _saved.logoAlignment ||
        _draft.logoPlacement != _saved.logoPlacement ||
        _draft.watermarkEnabled != _saved.watermarkEnabled ||
        _draft.watermarkOpacityPct != _saved.watermarkOpacityPct ||
        _draft.watermarkSize != _saved.watermarkSize ||
        _draft.watermarkPosition != _saved.watermarkPosition;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.refreshOrganization();
      final org = auth.organization;
      final identity = org?.visualIdentity ?? const OrgBranding();
      final uid = auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid;
      var canManage = false;
      if (org != null && uid != null) {
        final member = await OrganizationService.instance.getMembership(
          orgId: org.id,
          uid: uid,
          session: auth.restSession,
        );
        canManage = member?.role.canManageOrg ?? false;
      }
      final bytes = await BrandingStorageService.instance.loadLogoBytes(
        identity.logoUrl,
        organizationId: org?.id,
        uid: uid,
      );
      if (!mounted) return;
      setState(() {
        _saved = identity;
        _draft = identity;
        _previewBytes = bytes;
        _canManage = canManage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool> _ensurePro() async {
    final auth = context.read<AuthController>();
    if (auth.canCustomBranding) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.brandingProRequired)),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PricingScreen()),
    );
    if (!mounted) return false;
    return context.read<AuthController>().canCustomBranding;
  }

  Future<void> _pickLogo() async {
    if (_uploading || !_uploadGate.canStart) return;
    if (!await _ensurePro()) return;
    if (!mounted) return;
    if (!_canManage) {
      _showMessage(context.l10n.brandingOwnerOnly);
      return;
    }
    final auth = context.read<AuthController>();
    final orgId = auth.organizationId;
    final uid = auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid;
    if (orgId == null || uid == null) {
      _showMessage(context.l10n.needActiveOrganization);
      return;
    }

    // En Web, maxWidth/maxHeight del picker a veces demoran o fallan al
    // redimensionar; la validación/optimización la hace BrandingStorageService.
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e, st) {
      debugPrint('pickImage: $e\n$st');
      if (!mounted) return;
      _showMessage(context.l10n.imagePickerFailed);
      return;
    }
    // Cancelar el diálogo de archivos: no iniciar carga ni dejar spinner.
    if (picked == null) return;
    if (!mounted) return;
    final file = picked;
    final l10n = context.l10n;

    final previousPreview = _previewBytes;
    final previousDraft = _draft;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      await _uploadGate.run(() async {
        final bytes = await file.readAsBytes().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(l10n.imageReadTimeout);
          },
        );
        BrandingStorageService.instance.validateLogoBytes(
          bytes,
          fileName: file.name,
        );

        final online = await ConnectivityMonitor.instance.probeFirebase();
        late final OrgBranding next;
        var offlinePending = false;

        if (online) {
          final uploaded = await BrandingStorageService.instance.uploadOrgLogo(
            orgId: orgId,
            uid: uid,
            bytes: bytes,
            fileName: file.name,
          );
          next = previousDraft.copyWith(
            logoUrl: uploaded.url,
            logoStoragePath: uploaded.storagePath,
          );
          await BrandingLocalCache.instance.saveLogoBytes(
            organizationId: orgId,
            uid: uid,
            bytes: bytes,
            branding: next,
            pendingUpload: false,
          );
        } else {
          final localPath = await BrandingLocalCache.instance.saveLogoBytes(
            organizationId: orgId,
            uid: uid,
            bytes: bytes,
            branding: previousDraft,
            pendingUpload: true,
          );
          next = previousDraft.copyWith(
            logoUrl: localPath ?? previousDraft.logoUrl,
          );
          await OfflineLocalStore.instance.enqueue(
            organizationId: orgId,
            uid: uid,
            entityType: OfflineEntityType.brandingLogo,
            entityId: orgId,
            operation: OfflineOperation.uploadFile,
            payload: {'logoLocalPath': localPath, 'branding': next.toMap()},
            idempotencyKey: OfflineSyncService.idempotencyKey(
              type: OfflineEntityType.brandingLogo,
              entityId: orgId,
              op: OfflineOperation.uploadFile,
              revision: DateTime.now().toUtc().toIso8601String(),
            ),
          );
          await OfflineController.instance.refresh();
          offlinePending = true;
        }

        final saved = await auth
            .saveOrganizationBranding(next)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException(l10n.brandingFirestoreTimeout);
              },
            );
        if (!mounted) return;
        if (!saved) {
          throw Exception(
            auth.error != null
                ? localizeAuthError(l10n, auth.error)
                : l10n.logoUploadOrgSaveFailed,
          );
        }

        setState(() {
          _draft = next;
          _saved = next;
          _previewBytes = bytes;
          _error = null;
        });
        _showMessage(
          offlinePending ? l10n.logoSavedLocalPending : l10n.logoUploadedOk,
        );
      });
    } catch (e, st) {
      debugPrint('upload logo UI: $e\n$st');
      if (!mounted) return;
      final msg = BrandingStorageService.describeUploadError(e, l10n);
      setState(() {
        // Mantener logo anterior si el reemplazo falló.
        _draft = previousDraft;
        _previewBytes = previousPreview;
        _error = msg;
      });
      _showMessage(msg);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      } else {
        _uploading = false;
      }
    }
  }

  Future<void> _removeLogo() async {
    if (!await _ensurePro()) return;
    if (!mounted) return;
    if (!_canManage) {
      _showMessage(context.l10n.brandingOwnerOnly);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.removeLogoTitle),
          content: Text(l10n.removeLogoBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthController>();
    final orgId = auth.organizationId;
    final l10n = context.l10n;
    final previousDraft = _draft;
    final previousPreview = _previewBytes;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      if (orgId != null) {
        await BrandingStorageService.instance.deleteOrgLogo(
          orgId: orgId,
          storagePath: _draft.logoStoragePath,
        );
      }
      final next = previousDraft.copyWith(
        clearLogoUrl: true,
        clearLogoStoragePath: true,
        watermarkEnabled: false,
      );
      final saved = await auth.saveOrganizationBranding(next);
      if (!mounted) return;
      if (!saved) {
        throw Exception(
          auth.error != null
              ? localizeAuthError(l10n, auth.error)
              : l10n.orgUpdateWithoutLogoFailed,
        );
      }
      setState(() {
        _draft = next;
        _saved = next;
        _previewBytes = null;
      });
      _showMessage(l10n.logoRemovedOk);
    } catch (e, st) {
      debugPrint('remove logo: $e\n$st');
      if (!mounted) return;
      setState(() {
        _draft = previousDraft;
        _previewBytes = previousPreview;
        _error = BrandingStorageService.describeUploadError(e, l10n);
      });
      _showMessage(_error!);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      } else {
        _uploading = false;
      }
    }
  }

  Future<void> _save() async {
    if (!await _ensurePro()) return;
    if (!mounted) return;
    if (!_canManage) {
      _showMessage(context.l10n.brandingOwnerOnlySave);
      return;
    }
    final auth = context.read<AuthController>();
    final l10n = context.l10n;
    setState(() => _saving = true);
    final ok = await auth.saveOrganizationBranding(_draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _saved = _draft;
        _error = null;
      } else {
        _error = auth.error != null
            ? localizeAuthError(l10n, auth.error)
            : l10n.brandingSaveFailed;
      }
    });
    _showMessage(
      ok ? l10n.brandingSavedOk : (_error ?? l10n.saveErrorGeneric),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.unsavedExitTitle),
          content: Text(l10n.unsavedExitBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.keepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.exitWithoutSaving),
            ),
          ],
        );
      },
    );
    return r == true;
  }

  Future<void> _editColor(String key) async {
    if (!await _ensurePro()) return;
    if (!mounted) return;
    final colors = _colorsOf(_draft.colorsJson);
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
    setState(() {
      _draft = _draft.copyWith(colorsJson: jsonEncode(colors));
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

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l10n = context.l10n;
    final locked = !auth.canCustomBranding;
    final busy = _loading || _uploading || _saving;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (!leave || !mounted) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.visualIdentity),
          actions: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    l10n.unsavedChangesBadge,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.amber),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: ContentConstraint(
            padding: AppSpacing.page,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.visualIdentity,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (locked) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(l10n.proBadge),
                              visualDensity: VisualDensity.compact,
                              labelStyle: Theme.of(
                                context,
                              ).textTheme.labelSmall,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        locked ? l10n.visualIdentityPro : l10n.visualIdentityOk,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _LogoPreviewCard(
                        bytes: _previewBytes,
                        alignment: _draft.logoAlignment,
                        sizePt: _draft.logoSizePt,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            style: _tonalCompact,
                            onPressed: busy ? null : _pickLogo,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload_file_outlined),
                            label: Text(
                              _uploading
                                  ? l10n.uploadingLogo
                                  : (_draft.hasLogo
                                        ? l10n.changeLogo
                                        : l10n.uploadLogo),
                            ),
                          ),
                          if (_draft.hasLogo)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: busy ? null : _removeLogo,
                              icon: const Icon(Icons.delete_outline),
                              label: Text(l10n.removeLogoAction),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.logoSizeSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
                        value: _draft.logoSizePt,
                        min: OrgBranding.minLogoSizePt,
                        max: OrgBranding.maxLogoSizePt,
                        divisions: 12,
                        label: '${_draft.logoSizePt.round()} pt',
                        onChanged: busy || locked
                            ? null
                            : (v) => setState(() {
                                _draft = _draft.copyWith(logoSizePt: v);
                              }),
                      ),
                      Text(
                        l10n.alignmentSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<LogoAlignment>(
                        segments: [
                          for (final a in LogoAlignment.values)
                            ButtonSegment(
                              value: a,
                              label: Text(a.l10nLabel(l10n)),
                              icon: Icon(switch (a) {
                                LogoAlignment.left =>
                                  Icons.align_horizontal_left,
                                LogoAlignment.center =>
                                  Icons.align_horizontal_center,
                                LogoAlignment.right =>
                                  Icons.align_horizontal_right,
                              }),
                            ),
                        ],
                        selected: {_draft.logoAlignment},
                        onSelectionChanged: busy || locked
                            ? null
                            : (s) => setState(() {
                                _draft = _draft.copyWith(
                                  logoAlignment: s.first,
                                );
                              }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.pdfPlacementSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          l10n.pdfPlacementOnlyHeader(
                            LogoPlacement.header.l10nLabel(l10n),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.documentColors,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in _colorsOf(_draft.colorsJson).entries)
                            ActionChip(
                              avatar: CircleAvatar(
                                backgroundColor: _parseColor(e.value),
                                radius: 8,
                              ),
                              label: Text(e.key),
                              onPressed: busy || locked
                                  ? null
                                  : () => _editColor(e.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.watermarkSection,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.watermarkHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _draft.watermarkEnabled
                              ? l10n.watermarkEnabled
                              : l10n.watermarkDisabledHint,
                        ),
                        value: _draft.watermarkEnabled,
                        onChanged: busy || locked
                            ? null
                            : (v) {
                                if (v && !_draft.hasLogo) {
                                  _showMessage(l10n.watermarkNeedLogoFirst);
                                  return;
                                }
                                setState(() {
                                  _draft = _draft.copyWith(watermarkEnabled: v);
                                });
                              },
                      ),
                      if (!_draft.hasLogo)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            l10n.companyNoLogoYet,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      _WatermarkPreviewCard(
                        bytes: _previewBytes,
                        branding: _draft,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.watermarkTransparency(_draft.watermarkOpacityPct),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
                        value: _draft.watermarkOpacityPct.toDouble(),
                        min: OrgBranding.minWatermarkOpacityPct.toDouble(),
                        max: OrgBranding.maxWatermarkOpacityPct.toDouble(),
                        divisions:
                            OrgBranding.maxWatermarkOpacityPct -
                            OrgBranding.minWatermarkOpacityPct,
                        label: '${_draft.watermarkOpacityPct}%',
                        onChanged: busy || locked || !_draft.watermarkEnabled
                            ? null
                            : (v) => setState(() {
                                _draft = _draft.copyWith(
                                  watermarkOpacityPct: v.round(),
                                );
                              }),
                      ),
                      Text(
                        l10n.watermarkSizeTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<WatermarkSize>(
                        segments: [
                          for (final s in WatermarkSize.values)
                            ButtonSegment(
                              value: s,
                              label: Text(s.l10nLabel(l10n)),
                            ),
                        ],
                        selected: {_draft.watermarkSize},
                        onSelectionChanged:
                            busy || locked || !_draft.watermarkEnabled
                            ? null
                            : (s) => setState(() {
                                _draft = _draft.copyWith(
                                  watermarkSize: s.first,
                                );
                              }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.positionTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<WatermarkPosition>(
                        initialValue: _draft.watermarkPosition,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final p in WatermarkPosition.values)
                            DropdownMenuItem(
                              value: p,
                              child: Text(p.l10nLabel(l10n)),
                            ),
                        ],
                        onChanged: busy || locked || !_draft.watermarkEnabled
                            ? null
                            : (p) {
                                if (p == null) return;
                                setState(() {
                                  _draft = _draft.copyWith(
                                    watermarkPosition: p,
                                  );
                                });
                              },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: busy || !_dirty || locked ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.saveBrandingConfig),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.logoFitHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ),
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

class _LogoPreviewCard extends StatelessWidget {
  const _LogoPreviewCard({
    required this.bytes,
    required this.alignment,
    required this.sizePt,
  });

  final Uint8List? bytes;
  final LogoAlignment alignment;
  final double sizePt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = switch (alignment) {
      LogoAlignment.left => Alignment.centerLeft,
      LogoAlignment.center => Alignment.center,
      LogoAlignment.right => Alignment.centerRight,
    };
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: bytes == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 40,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.emptyCompanyNoLogo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : Align(
              alignment: align,
              child: Image.memory(
                bytes!,
                height: sizePt.clamp(24, 96),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
    );
  }
}

/// Vista previa de página A4 simplificada con marca de agua.
class _WatermarkPreviewCard extends StatelessWidget {
  const _WatermarkPreviewCard({required this.bytes, required this.branding});

  final Uint8List? bytes;
  final OrgBranding branding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final showMark = branding.watermarkEnabled && bytes != null;
    final align = switch (branding.watermarkPosition) {
      WatermarkPosition.center => Alignment.center,
      WatermarkPosition.topCenter => Alignment.topCenter,
      WatermarkPosition.bottomCenter => Alignment.bottomCenter,
      WatermarkPosition.bottomRight => Alignment.bottomRight,
    };
    final markSize = switch (branding.watermarkSize) {
      WatermarkSize.small => 56.0,
      WatermarkSize.medium => 88.0,
      WatermarkSize.large => 120.0,
    };

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (showMark)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: align,
                  child: Opacity(
                    opacity: branding.watermarkOpacity,
                    child: Image.memory(
                      bytes!,
                      width: markSize,
                      height: markSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 28,
                    width: double.infinity,
                    color: const Color(0xFF1A1A2E),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      l10n.previewQuoteHeader,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 8,
                    width: 160,
                    color: const Color(0xFFE0E0E0),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    width: 220,
                    color: const Color(0xFFE0E0E0),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    width: 180,
                    color: const Color(0xFFE0E0E0),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      l10n.previewSampleTotal,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (!branding.watermarkEnabled)
                    Text(
                      l10n.watermarkDisabledHint,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
