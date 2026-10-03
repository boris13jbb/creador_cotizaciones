import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../saas/config/saas_config.dart';
import '../../saas/providers/auth_controller.dart';
import '../../ui/tokens/app_spacing.dart';

/// Primer inicio: el usuario nombra su empresa antes de usar Clientes/Catálogo.
class SetupOrganizationScreen extends StatefulWidget {
  const SetupOrganizationScreen({super.key});

  @override
  State<SetupOrganizationScreen> createState() =>
      _SetupOrganizationScreenState();
}

class _SetupOrganizationScreenState extends State<SetupOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Mi empresa');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      final hint = auth.profile?.displayName ?? auth.user?.displayName ?? '';
      if (hint.isNotEmpty && _nameCtrl.text == 'Mi empresa') {
        _nameCtrl.text = '$hint — Empresa';
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    setState(() => _submitting = true);
    final ok = await auth.createOrRecoverOrganization(
      organizationName: _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      final msg = auth.error ?? 'No se pudo crear la organización.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + bottomInset,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Crea tu organización',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'En ${SaasConfig.productName} cada cuenta trabaja '
                      'dentro de una empresa. Así guardamos clientes, '
                      'catálogo y cotizaciones.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.done,
                      enabled: !_submitting && !auth.loading,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la empresa',
                        hintText: 'Ej. Servicios JB',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Ingresa el nombre de la empresa';
                        if (t.length < 2) return 'Nombre demasiado corto';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (auth.error != null && auth.error!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        auth.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: (_submitting || auth.loading) ? null : _submit,
                      child: (_submitting || auth.loading)
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continuar'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: (_submitting || auth.loading)
                          ? null
                          : () => auth.signOut(),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
