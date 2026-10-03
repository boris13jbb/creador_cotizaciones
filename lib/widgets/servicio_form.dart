import 'package:flutter/material.dart';
import '../models/servicio.dart';

class ServicioForm extends StatefulWidget {
  final Function(Servicio) onAgregado;
  final Servicio? servicioExistente;

  const ServicioForm({
    super.key,
    required this.onAgregado,
    this.servicioExistente,
  });

  @override
  State<ServicioForm> createState() => _ServicioFormState();
}

class _ServicioFormState extends State<ServicioForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.servicioExistente != null) {
      _nombreController.text = widget.servicioExistente!.nombre;
      _descripcionController.text = widget.servicioExistente!.descripcion;
      _precioController.text = widget.servicioExistente!.precio.toString();
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.servicioExistente != null
                    ? 'Editar Servicio/Módulo'
                    : 'Agregar Servicio/Módulo',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Servicio',
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v!) == null ? 'Número inválido' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final servicio = Servicio(
                      nombre: _nombreController.text,
                      descripcion: _descripcionController.text,
                      precio: double.parse(_precioController.text),
                    );
                    widget.onAgregado(servicio);
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  widget.servicioExistente != null
                      ? 'Guardar Cambios'
                      : 'Agregar',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
