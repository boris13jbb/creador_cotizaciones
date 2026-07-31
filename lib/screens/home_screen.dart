import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cotizacion.dart';
import '../services/db_service.dart';
import '../saas/providers/auth_controller.dart';
import '../widgets/cotizacion_card.dart';
import 'account/account_screen.dart';
import 'account/pricing_screen.dart';
import 'historial_screen.dart';
import 'nueva_cotizacion_screen.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Cotizacion>> _cotizacionesFuture;
  final Set<String> _cotizacionesOcultas = {};

  @override
  void initState() {
    super.initState();
    _refreshLista();
  }

  void _refreshLista() {
    setState(() {
      _cotizacionesFuture = DBService.instance.obtenerTodas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CotiApp'),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Chip(
                  label: Text(profile.plan.label, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Planes',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PricingScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mi cuenta',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLista,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshLista(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(13),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Qué deseas crear hoy?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMainButton(
                            context,
                            title: 'Nueva\nCotización',
                            icon: Icons.add_chart,
                            color: Colors.blue,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const NuevaCotizacionScreen()),
                              );
                              _refreshLista();
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildMainButton(
                            context,
                            title: 'Historial\nCotizaciones',
                            icon: Icons.history,
                            color: Colors.indigo,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HistorialScreen()),
                              );
                              _refreshLista();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cotizaciones Recientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistorialScreen()),
                        );
                        _refreshLista();
                      },
                      child: const Text('Ver todas'),
                    ),
                  ],
                ),
              ),
              _buildRecientesCotizaciones(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NuevaCotizacionScreen()),
          );
          _refreshLista();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva cotización'),
      ),
    );
  }

  Widget _buildRecientesCotizaciones() {
    return FutureBuilder<List<Cotizacion>>(
      future: _cotizacionesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        final allCotizaciones = snapshot.data ?? [];
        final cotizaciones = allCotizaciones.where((c) => !_cotizacionesOcultas.contains(c.id)).toList();
        if (cotizaciones.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No hay cotizaciones recientes', style: TextStyle(color: Colors.grey)),
          );
        }
        final recientes = cotizaciones.take(5).toList();
        return Column(
          children: recientes
              .map(
                (cot) => CotizacionCard(
                  cotizacion: cot,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PreviewScreen(cotizacion: cot)),
                    );
                    _refreshLista();
                  },
                  onEdit: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NuevaCotizacionScreen(cotizacion: cot)),
                    );
                    _refreshLista();
                  },
                  onHide: () => setState(() => _cotizacionesOcultas.add(cot.id)),
                  onDelete: () async {
                    final confirm = await _mostrarConfirmacion(context, 'Cotización ${cot.numero}');
                    if (confirm == true) {
                      await DBService.instance.eliminarCotizacion(cot.id);
                      _refreshLista();
                    }
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withAlpha(13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(76), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _mostrarConfirmacion(BuildContext context, String item) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Estás seguro de eliminar $item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
