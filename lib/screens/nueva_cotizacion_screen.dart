import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/simple_color_dialog.dart';

import '../models/cotizacion.dart';
import '../models/forma_pago_item.dart';
import '../models/servicio.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/servicio_form.dart';

class NuevaCotizacionScreen extends StatefulWidget {
  final Cotizacion? cotizacion;

  const NuevaCotizacionScreen({super.key, this.cotizacion});

  @override
  State<NuevaCotizacionScreen> createState() => _NuevaCotizacionScreenState();
}

class _NuevaCotizacionScreenState extends State<NuevaCotizacionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _clienteController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _tipoServicioController = TextEditingController();
  final _cantidadEquiposController = TextEditingController();
  final _tiempoEstimadoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _subtituloController = TextEditingController();
  final _validezDiasController = TextEditingController();
  final _footerController = TextEditingController();
  final _firmaTecnicoController = TextEditingController();
  final _firmaClienteController = TextEditingController();
  final _numeroController = TextEditingController();
  
  final _fp1Etiqueta = TextEditingController(text: 'ANTICIPO');
  final _fp1Desc = TextEditingController(text: '50% al iniciar');
  final _fp1Monto = TextEditingController();
  final _fp2Etiqueta = TextEditingController(text: 'ENTREGA PARCIAL');
  final _fp2Desc = TextEditingController(text: '25% a mitad del proyecto');
  final _fp2Monto = TextEditingController();
  final _fp3Etiqueta = TextEditingController(text: 'SALDO FINAL');
  final _fp3Desc = TextEditingController(text: '25% al entregar');
  final _fp3Monto = TextEditingController();

  final _colorPrimaryController = TextEditingController();
  final _colorSecondaryController = TextEditingController();
  final _colorAccentController = TextEditingController();
  final _colorSuccessController = TextEditingController();
  final _colorErrorController = TextEditingController();

  final _incluyeItemController = TextEditingController();
  final _noIncluyeItemController = TextEditingController();
  final _notasItemController = TextEditingController();

  final List<Servicio> _servicios = [];
  final List<String> _incluye = [];
  final List<String> _noIncluye = [];
  final List<String> _notas = [];
  final List<MapEntry<String, String>> _camposExtra = [];
  final _campoExtraLabel = TextEditingController();
  final _campoExtraValue = TextEditingController();

  String? _logoPath;
  List<int>? _logoBytes; 
  bool _isPickingImage = false; 
  late String _fechaActual;

  double get _total => _servicios.fold(0, (sum, item) => sum + item.precio);

  @override
  void initState() {
    super.initState();
    if (widget.cotizacion != null) {
      final cot = widget.cotizacion!;
      _clienteController.text = cot.cliente;
      _ubicacionController.text = cot.ubicacion;
      _tipoServicioController.text = cot.tipoServicio;
      _cantidadEquiposController.text = cot.cantidadEquipos;
      _tiempoEstimadoController.text = cot.tiempoEstimado;
      _descripcionController.text = cot.descripcion;
      _subtituloController.text = cot.subtitulo ?? '';
      _validezDiasController.text = cot.validezDias?.toString() ?? '';
      _footerController.text = cot.footerText ?? '';
      _firmaTecnicoController.text = cot.firmaTecnicoLabel ?? '';
      _firmaClienteController.text = cot.firmaClienteLabel ?? '';
      _numeroController.text = cot.numero;

      // Manejo de colores personalizados
      if (cot.coloresJson != null && cot.coloresJson!.isNotEmpty) {
        try {
          final colores = jsonDecode(cot.coloresJson!) as Map<String, dynamic>;
          _colorPrimaryController.text = colores['primary'] as String;
          _colorSecondaryController.text = colores['secondary'] as String;
          _colorAccentController.text = colores['accent'] as String;
          _colorSuccessController.text = colores['success'] as String;
          _colorErrorController.text = colores['error'] as String;
        } catch (_) {
          // Si hay error al decodificar, usar valores por defecto
        }
      }
      
      final fp = cot.formaPago;
      if (fp.length >= 3) {
        _fp1Etiqueta.text = fp[0].etiqueta;
        _fp1Desc.text = fp[0].descripcion;
        _fp1Monto.text = fp[0].monto.toString();
        _fp2Etiqueta.text = fp[1].etiqueta;
        _fp2Desc.text = fp[1].descripcion;
        _fp2Monto.text = fp[1].monto.toString();
        _fp3Etiqueta.text = fp[2].etiqueta;
        _fp3Desc.text = fp[2].descripcion;
        _fp3Monto.text = fp[2].monto.toString();
      }

      _servicios.addAll(cot.servicios);
      _incluye.addAll(cot.incluye);
      _noIncluye.addAll(cot.noIncluye);
      _notas.addAll(cot.notas);
      _camposExtra.addAll(cot.camposExtraList);
      _logoPath = cot.logoPath;
      _fechaActual = cot.fecha;

      if (_logoPath != null && _logoPath!.startsWith('data:')) {
        try {
          final base64 = _logoPath!.split(',').last;
          _logoBytes = base64Decode(base64);
        } catch (_) {}
      }
    } else {
      _fechaActual = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
      _generarNuevoNumero();
    }
  }

  Future<void> _generarNuevoNumero() async {
    final prefijo = await DBService.instance.getPrefijo();
    final numero = await DBService.instance.getProximoNumero();
    if (mounted) {
      setState(() {
        _numeroController.text = "$prefijo-${numero.toString().padLeft(3, '0')}";
      });
    }
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _ubicacionController.dispose();
    _tipoServicioController.dispose();
    _cantidadEquiposController.dispose();
    _tiempoEstimadoController.dispose();
    _descripcionController.dispose();
    _subtituloController.dispose();
    _validezDiasController.dispose();
    _footerController.dispose();
    _firmaTecnicoController.dispose();
    _firmaClienteController.dispose();
    _numeroController.dispose();
    _fp1Etiqueta.dispose();
    _fp1Desc.dispose();
    _fp1Monto.dispose();
    _fp2Etiqueta.dispose();
    _fp2Desc.dispose();
    _fp2Monto.dispose();
    _fp3Etiqueta.dispose();
    _fp3Desc.dispose();
    _fp3Monto.dispose();
    _campoExtraLabel.dispose();
    _campoExtraValue.dispose();
    _incluyeItemController.dispose();
    _noIncluyeItemController.dispose();
    _notasItemController.dispose();
    _colorPrimaryController.dispose();
    _colorSecondaryController.dispose();
    _colorAccentController.dispose();
    _colorSuccessController.dispose();
    _colorErrorController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarLogo() async {
    if (_isPickingImage) return; 

    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _logoBytes = bytes;
          _logoPath = kIsWeb
              ? 'data:image/jpeg;base64,${base64Encode(bytes)}'
              : pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint("Error al seleccionar imagen: $e");
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  DecorationImage? _buildLogoDecorationImage() {
    if (_logoPath == null) return null;
    if (_logoBytes != null) {
      return DecorationImage(
        image: MemoryImage(Uint8List.fromList(_logoBytes!)),
        fit: BoxFit.cover,
      );
    }
    if (_logoPath!.startsWith('data:')) {
      try {
        final base64 = _logoPath!.split(',').last;
        return DecorationImage(
          image: MemoryImage(base64Decode(base64)),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return null;
      }
    }
    if (!kIsWeb) {
      return DecorationImage(
        image: FileImage(File(_logoPath!)),
        fit: BoxFit.cover,
      );
    }
    return DecorationImage(
      image: NetworkImage(_logoPath!),
      fit: BoxFit.cover,
    );
  }

  void _agregarItemLista(List<String> lista, TextEditingController controller) {
    if (controller.text.isNotEmpty) {
      setState(() {
        lista.add(controller.text);
        controller.clear();
      });
    }
  }

  Future<void> _guardarCotizacion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_servicios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un servicio')),
      );
      return;
    }

    String? formaPagoJson;
    final fpList = _buildFormaPago();
    if (fpList.isNotEmpty) {
      formaPagoJson = jsonEncode(fpList.map((e) => e.toJson()).toList());
    }
    final camposExtraStr = _camposExtra.isEmpty
        ? null
        : _camposExtra.map((e) => '${e.key}|${e.value}').join('|');

    final nuevaCot = Cotizacion(
      id: widget.cotizacion?.id ?? const Uuid().v4(),
      numero: _numeroController.text,
      fecha: _fechaActual,
      cliente: _clienteController.text,
      ubicacion: _ubicacionController.text,
      tipoServicio: _tipoServicioController.text,
      cantidadEquipos: _cantidadEquiposController.text,
      tiempoEstimado: _tiempoEstimadoController.text,
      descripcion: _descripcionController.text,
      servicios: List.from(_servicios),
      total: _total,
      incluye: List.from(_incluye),
      noIncluye: List.from(_noIncluye),
      notas: List.from(_notas),
      logoPath: _logoPath,
      subtitulo: _subtituloController.text.isEmpty ? null : _subtituloController.text,
      validezDias: int.tryParse(_validezDiasController.text),
      footerText: _footerController.text.isEmpty ? null : _footerController.text,
      firmaTecnicoLabel: _firmaTecnicoController.text.isEmpty ? null : _firmaTecnicoController.text,
      firmaClienteLabel: _firmaClienteController.text.isEmpty ? null : _firmaClienteController.text,
      formaPagoJson: formaPagoJson,
      camposExtra: camposExtraStr,
      coloresJson: _buildColoresJson(),
    );

    await DBService.instance.insertarCotizacion(nuevaCot);
    
    if (widget.cotizacion == null) {
      await DBService.instance.incrementarNumero();
    }

    if (mounted) Navigator.pop(context, true);
  }

  List<FormaPagoItem> _buildFormaPago() {
    final total = _total;
    double? m1 = double.tryParse(_fp1Monto.text);
    double? m2 = double.tryParse(_fp2Monto.text);
    double? m3 = double.tryParse(_fp3Monto.text);
    if (m1 == null && m2 == null && m3 == null) {
      m1 = total * 0.5;
      m2 = total * 0.25;
      m3 = total * 0.25;
    }
    m1 ??= 0; m2 ??= 0; m3 ??= 0;
    return [
      FormaPagoItem(etiqueta: _fp1Etiqueta.text, descripcion: _fp1Desc.text, monto: m1),
      FormaPagoItem(etiqueta: _fp2Etiqueta.text, descripcion: _fp2Desc.text, monto: m2),
      FormaPagoItem(etiqueta: _fp3Etiqueta.text, descripcion: _fp3Desc.text, monto: m3),
    ];
  }

  void _mostrarConfiguracionContador() {
    final prefijoCtrl = TextEditingController();
    final numeroCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogCtx) => FutureBuilder(
        future: Future.wait([
          DBService.instance.getPrefijo(),
          DBService.instance.getProximoNumero(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          prefijoCtrl.text = snapshot.data![0] as String;
          numeroCtrl.text = (snapshot.data![1] as int).toString();

          return AlertDialog(
            title: const Text('Configurar Numeración'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prefijoCtrl,
                  decoration: const InputDecoration(labelText: 'Prefijo (ej: COT)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: numeroCtrl,
                  decoration: const InputDecoration(labelText: 'Próximo Número'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(dialogCtx);
                  await DBService.instance.configurarPrefijo(prefijoCtrl.text);
                  await DBService.instance.configurarNumero(int.tryParse(numeroCtrl.text) ?? 1);
                  navigator.pop();
                  if (mounted) {
                    _generarNuevoNumero();
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _buildColoresJson() {
    if (_colorPrimaryController.text.isEmpty &&
        _colorSecondaryController.text.isEmpty &&
        _colorAccentController.text.isEmpty &&
        _colorSuccessController.text.isEmpty &&
        _colorErrorController.text.isEmpty) {
      return null;
    }
    
    final palette = {
      'primary': _colorPrimaryController.text.isNotEmpty ? _colorPrimaryController.text : '#1A1A2E',
      'secondary': _colorSecondaryController.text.isNotEmpty ? _colorSecondaryController.text : '#2D6A4F',
      'accent': _colorAccentController.text.isNotEmpty ? _colorAccentController.text : '#40916C',
      'success': _colorSuccessController.text.isNotEmpty ? _colorSuccessController.text : '#D8F3DC',
      'error': _colorErrorController.text.isNotEmpty ? _colorErrorController.text : '#FFE5E5',
    };
    
    return jsonEncode(palette);
  }

  Widget _buildColorPicker(TextEditingController controller, String label, Color defaultColor) {
    Color currentColor = defaultColor;
    if (controller.text.isNotEmpty) {
      try {
        currentColor = Color(int.parse(controller.text.replaceAll('#', '0xFF')));
      } catch (_) {}
    }
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: currentColor,
            border: Border.all(color: Colors.grey, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: '#RRGGBB',
              suffixIcon: IconButton(
                icon: const Icon(Icons.color_lens, size: 18),
                onPressed: () async {
                  // Implementación simplificada del selector de color
                  final colorStr = await showDialog<String>(
                    context: context,
                    builder: (context) => SimpleColorDialog(controller.text),
                  );
                  if (colorStr != null && mounted) {
                    setState(() {
                      controller.text = colorStr;
                    });
                  }
                },
              ),
            ),
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              final hexPattern = RegExp(r'^#([A-Fa-f0-9]{8}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$');
              if (!hexPattern.hasMatch(value)) {
                return 'Formato inválido. Use #RRGGBB o #AARRGGBB';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.cotizacion != null;
    return Scaffold(
      appBar: AppBar(title: Text(esEdicion ? 'Editar Cotización' : 'Nueva Cotización')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSeccionTitulo("Información General"),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_numeroController, "Nº Cotización"),
                  ),
                  if (!esEdicion)
                    IconButton(
                      icon: const Icon(Icons.settings, color: AppTheme.primaryDark),
                      onPressed: _mostrarConfiguracionContador,
                      tooltip: "Configurar numeración",
                    ),
                ],
              ),
              _buildTextField(_clienteController, "Cliente / Institución"),
              _buildTextField(_ubicacionController, "Ubicación"),
              _buildTextField(_tipoServicioController, "Tipo de Servicio"),
              Row(
                children: [
                  Expanded(child: _buildTextField(_cantidadEquiposController, "Cant. Equipos")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(_tiempoEstimadoController, "Tiempo Estimado")),
                ],
              ),
              _buildTextField(_descripcionController, "Descripción Breve", maxLines: 3),
              
              const SizedBox(height: 20),
              _buildSeccionTitulo("Logo de Empresa"),
              Center(
                child: GestureDetector(
                  onTap: _isPickingImage ? null : _seleccionarLogo,
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      image: _buildLogoDecorationImage(),
                    ),
                    child: _logoPath == null 
                      ? (_isPickingImage 
                          ? const CircularProgressIndicator() 
                          : const Icon(Icons.add_a_photo, size: 40)) 
                      : null,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildSeccionTitulo("Servicios / Módulos"),
              ..._servicios.asMap().entries.map((entry) {
                final index = entry.key;
                final s = entry.value;
                return ListTile(
                  key: ValueKey(s.nombre + s.precio.toString() + index.toString()),
                  title: Text(s.nombre),
                  subtitle: Text(s.descripcion),
                  trailing: Text('\$${s.precio.toStringAsFixed(2)}'),
                  onTap: () => _mostrarDialogoServicio(servicio: s, index: index),
                  onLongPress: () => setState(() => _servicios.removeAt(index)),
                );
              }),
              TextButton.icon(
                onPressed: () => _mostrarDialogoServicio(),
                icon: const Icon(Icons.add),
                label: const Text("Agregar Servicio"),
              ),

              const SizedBox(height: 20),
              _buildInputLista("Incluye", _incluye, _incluyeItemController),
              _buildInputLista("No Incluye", _noIncluye, _noIncluyeItemController),
              _buildInputLista("Notas Importantes", _notas, _notasItemController),

              const SizedBox(height: 20),
              _buildSeccionTitulo("Opciones de documento (opcional)"),
              _buildTextFieldOptional(_subtituloController, "Subtítulo"),
              Row(
                children: [
                  Expanded(child: _buildTextFieldOptional(_validezDiasController, "Validez (días)", keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextFieldOptional(_footerController, "Pie de página")),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextFieldOptional(_firmaTecnicoController, "Firma técnico")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextFieldOptional(_firmaClienteController, "Firma cliente")),
                ],
              ),

              const SizedBox(height: 16),
              _buildSeccionTitulo("Colores Personalizados"),
              const SizedBox(height: 8),
              _buildColorPicker(_colorPrimaryController, "Primario", const Color(0xFF1A1A2E)),
              const SizedBox(height: 8),
              _buildColorPicker(_colorSecondaryController, "Secundario", const Color(0xFF2D6A4F)),
              const SizedBox(height: 8),
              _buildColorPicker(_colorAccentController, "Acento", const Color(0xFF40916C)),
              const SizedBox(height: 8),
              _buildColorPicker(_colorSuccessController, "Éxito", const Color(0xFFD8F3DC)),
              const SizedBox(height: 8),
              _buildColorPicker(_colorErrorController, "Error", const Color(0xFFFFE5E5)),
              
              const SizedBox(height: 16),
              _buildSeccionTitulo("Forma de pago"),
              _buildFilaFormaPago(_fp1Etiqueta, _fp1Desc, _fp1Monto),
              _buildFilaFormaPago(_fp2Etiqueta, _fp2Desc, _fp2Monto),
              _buildFilaFormaPago(_fp3Etiqueta, _fp3Desc, _fp3Monto),

              const SizedBox(height: 16),
              _buildSeccionTitulo("Campos extra"),
              ..._camposExtra.map((e) => ListTile(
                key: ValueKey(e.key + e.value),
                title: Text(e.key),
                subtitle: Text(e.value),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => setState(() => _camposExtra.remove(e)),
                ),
              )),
              _buildAgregarCampoExtra(),

              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL ESTIMADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("\$${_total.toStringAsFixed(2)}", 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardarCotizacion,
                  child: Text(esEdicion ? "ACTUALIZAR COTIZACIÓN" : "GUARDAR COTIZACIÓN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        maxLines: maxLines,
        validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
      ),
    );
  }

  Widget _buildTextFieldOptional(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: 'Opcional'),
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildFilaFormaPago(TextEditingController etiq, TextEditingController desc, TextEditingController monto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: TextFormField(controller: etiq, decoration: const InputDecoration(labelText: 'Etiqueta'), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Descripción'), onChanged: (_) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(controller: monto, decoration: const InputDecoration(labelText: '\$'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
        ],
      ),
    );
  }

  Widget _buildAgregarCampoExtra() {
    return Row(
      children: [
        Expanded(child: TextField(controller: _campoExtraLabel, decoration: const InputDecoration(hintText: 'Etiqueta'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _campoExtraValue, decoration: const InputDecoration(hintText: 'Valor'))),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: () {
            final label = _campoExtraLabel.text.trim();
            final value = _campoExtraValue.text.trim();
            if (label.isNotEmpty || value.isNotEmpty) {
              setState(() {
                _camposExtra.add(MapEntry(label.isEmpty ? 'Campo' : label, value));
                _campoExtraLabel.clear();
                _campoExtraValue.clear();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildInputLista(String titulo, List<String> lista, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeccionTitulo(titulo),
        Wrap(
          spacing: 8,
          children: lista.map((item) => Chip(
            key: ValueKey(item),
            label: Text(item),
            onDeleted: () => setState(() => lista.remove(item)),
          )).toList(),
        ),
        Row(
          children: [
            Expanded(child: TextField(controller: controller, decoration: InputDecoration(hintText: "Agregar..."))),
            IconButton(icon: const Icon(Icons.add_circle), onPressed: () => _agregarItemLista(lista, controller)),
          ],
        ),
      ],
    );
  }

  void _mostrarDialogoServicio({Servicio? servicio, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ServicioForm(
        servicioExistente: servicio,
        onAgregado: (s) {
          setState(() {
            if (index != null) {
              _servicios[index] = s;
            } else {
              _servicios.add(s);
            }
          });
        },
      ),
    );
  }
}




