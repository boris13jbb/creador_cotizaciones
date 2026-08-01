import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../saas/providers/auth_controller.dart';
import '../../saas/providers/quote_editor_controller.dart';
import '../../saas/services/branding_storage_service.dart';
import '../../ui/layout/responsive.dart';
import '../../widgets/simple_color_dialog.dart';
import '../account/pricing_screen.dart';

/// Logo y colores de cotización (requiere entitlement Pro / trial).
class QuoteBrandingSection extends StatefulWidget {
  const QuoteBrandingSection({super.key, required this.controller});

  final QuoteEditorController controller;

  @override
  State<QuoteBrandingSection> createState() => _QuoteBrandingSectionState();
}

class _QuoteBrandingSectionState extends State<QuoteBrandingSection> {
  bool _uploading = false;

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
    final auth = context.read<AuthController>();
    if (!auth.canCustomBranding) {
      await _ensurePro();
      return;
    }
    final uid = auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para subir el logo.')),
      );
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await BrandingStorageService.instance.uploadLogo(
        uid: uid,
        bytes: bytes,
      );
      widget.controller.setLogoPath(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _clearLogo() async {
    final auth = context.read<AuthController>();
    if (!auth.canCustomBranding) {
      await _ensurePro();
      return;
    }
    final uid = auth.user?.uid ?? auth.restSession?.uid ?? auth.profile?.uid;
    if (uid != null) {
      await BrandingStorageService.instance.deleteLogo(uid);
    }
    widget.controller.setLogoPath(null);
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
    // SimpleColorDialog a veces devuelve #AARRGGBB
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Branding', style: Theme.of(context).textTheme.titleSmall),
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
              : 'Logo y colores del PDF/DOCX.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _uploading ? null : _pickLogo,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(
                q.logoPath == null || q.logoPath!.isEmpty
                    ? 'Subir logo'
                    : 'Cambiar logo',
              ),
            ),
            if (q.logoPath != null && q.logoPath!.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _uploading ? null : _clearLogo,
                child: const Text('Quitar'),
              ),
            ],
          ],
        ),
        if (q.logoPath != null && q.logoPath!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              q.logoPath!.startsWith('data:')
                  ? 'Logo en dispositivo (escritorio)'
                  : 'Logo listo para PDF',
              style: Theme.of(context).textTheme.labelSmall,
            ),
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
