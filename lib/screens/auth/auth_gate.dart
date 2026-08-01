import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../saas/providers/auth_controller.dart';
import '../../ui/layout/app_shell.dart';
import 'login_screen.dart';
import 'setup_organization_screen.dart';

/// Decide entre login, setup de organización y app según sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.loading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Cargando sesión',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.needsOrganizationSetup) {
      return const SetupOrganizationScreen();
    }

    return const AppShell();
  }
}
