import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin_api.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminConsoleApp());
}

class AdminConsoleApp extends StatelessWidget {
  const AdminConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CotiApp Super Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C5C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const _LoginPage();
        return _HomePage(user: user);
      },
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage();

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _bootstrapSecret = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await AdminApi().bootstrap(_bootstrapSecret.text.trim());
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Super admin activado. Si no ves el panel, cierra sesión y vuelve a entrar.',
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _bootstrapSecret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CotiApp Super Admin',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Consola de monitoreo y permisos gratis',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bootstrapSecret,
                    decoration: const InputDecoration(
                      labelText: 'Secreto bootstrap (solo primer admin)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _bootstrap,
                    child: const Text('Activar primer super admin'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.user});
  final User user;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _api = AdminApi();
  final _search = TextEditingController();
  final _reason = TextEditingController(text: 'Acceso cortesía / piloto');
  String _plan = 'business';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;
  List<dynamic> _grants = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.user.getIdToken(true);
      final stats = await _api.stats();
      final grants = await _api.listGrants();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _grants = (grants['grants'] as List?) ?? [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookup() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _user = null;
    });
    try {
      final isEmail = q.contains('@');
      final result = await _api.lookupUser(
        email: isEmail ? q : null,
        uid: isEmail ? null : q,
      );
      if (!mounted) return;
      setState(() => _user = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grant() async {
    final uid = _user?['uid'] as String?;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await _api.grant(
        uid: uid,
        plan: _plan,
        reason: _reason.text.trim(),
      );
      await _lookup();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acceso gratis otorgado')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke() async {
    final uid = _user?['uid'] as String?;
    if (uid == null) return;
    final grantId = (_user?['entitlements'] as Map?)?['grantId'] as String?;
    setState(() => _loading = true);
    try {
      await _api.revoke(uid: uid, grantId: grantId);
      await _lookup();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acceso revocado')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = _user?['entitlements'] as Map?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin · CotiApp'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sesión: ${widget.user.email ?? widget.user.uid}'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(label: 'Usuarios', value: '${_stats?['users'] ?? '—'}'),
              _StatChip(
                label: 'Organizaciones',
                value: '${_stats?['organizations'] ?? '—'}',
              ),
              _StatChip(
                label: 'Grants activos',
                value: '${_stats?['activeGrants'] ?? '—'}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Buscar cliente', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Email o UID',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _lookup,
                child: const Text('Buscar'),
              ),
            ],
          ),
          if (_user != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user!['email']?.toString() ?? 'Sin email',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('UID: ${_user!['uid']}'),
                    Text('Nombre: ${_user!['displayName'] ?? '—'}'),
                    Text(
                      'Plan actual: ${ent?['plan'] ?? '—'} · '
                      '${ent?['subscriptionStatus'] ?? '—'} · '
                      'source=${ent?['source'] ?? '—'}',
                    ),
                    if (ent?['grantReason'] != null)
                      Text('Motivo grant: ${ent?['grantReason']}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _plan,
                      decoration: const InputDecoration(
                        labelText: 'Plan a otorgar',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pro', child: Text('Pro')),
                        DropdownMenuItem(
                          value: 'business',
                          child: Text('Business (todo el sistema)'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _plan = v ?? 'business'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reason,
                      decoration: const InputDecoration(
                        labelText: 'Motivo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _loading ? null : _grant,
                          icon: const Icon(Icons.card_giftcard),
                          label: const Text('Dar acceso gratis'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _revoke,
                          icon: const Icon(Icons.block),
                          label: const Text('Revocar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Grants recientes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loading && _grants.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_grants.isEmpty)
            const Text('Sin grants todavía')
          else
            ..._grants.map((g) {
              final m = Map<String, dynamic>.from(g as Map);
              final revoked = m['revokedAt'] != null;
              return ListTile(
                leading: Icon(
                  revoked ? Icons.block : Icons.verified,
                  color: revoked ? Colors.grey : Colors.green,
                ),
                title: Text('${m['targetUid']} · ${m['plan']}'),
                subtitle: Text(
                  '${m['reason'] ?? ''}\n${m['createdAt'] ?? ''}'
                  '${revoked ? ' · REVOCADO' : ''}',
                ),
                isThreeLine: true,
              );
            }),
          const SizedBox(height: 24),
          Text(
            'Errores recientes (cliente)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...(((_stats?['recentErrors'] as List?) ?? []).map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return ListTile(
              dense: true,
              title: Text('${m['message'] ?? ''}'),
              subtitle: Text('${m['uid'] ?? ''} · ${m['createdAt'] ?? ''}'),
            );
          })),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
