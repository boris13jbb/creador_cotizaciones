import 'package:flutter/material.dart';
import '../models/cotizacion.dart';
import '../services/db_service.dart';
import '../widgets/cotizacion_card.dart';
import 'preview_screen.dart';
import 'nueva_cotizacion_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _queryController = TextEditingController();
  late Future<List<Cotizacion>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = DBService.instance.obtenerTodas();
    });
  }

  List<Cotizacion> _filtrar(List<Cotizacion> cotizaciones, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return cotizaciones;

    bool match(Cotizacion c) {
      return c.numero.toLowerCase().contains(query) ||
          c.cliente.toLowerCase().contains(query) ||
          c.ubicacion.toLowerCase().contains(query) ||
          c.tipoServicio.toLowerCase().contains(query);
    }

    return cotizaciones.where(match).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Buscar por número, cliente, ubicación o servicio',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Cotizacion>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final all = snapshot.data ?? [];
                final filtered = _filtrar(all, _queryController.text);

                if (all.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'Aún no hay cotizaciones guardadas',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'Sin resultados para tu búsqueda',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final cot = filtered[index];
                    return CotizacionCard(
                      cotizacion: cot,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PreviewScreen(cotizacion: cot),
                          ),
                        );
                        if (result == true) {
                          _refresh();
                        }
                      },
                      onEdit: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NuevaCotizacionScreen(cotizacion: cot),
                          ),
                        );
                        if (result == true) {
                          _refresh();
                        }
                      },
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar'),
                            content: Text('¿Eliminar la cotización ${cot.numero}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await DBService.instance.eliminarCotizacion(cot.id);
                          _refresh();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
