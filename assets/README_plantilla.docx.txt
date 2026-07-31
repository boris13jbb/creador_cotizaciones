CotiApp - Plantilla Word (DOCX)
==============================

La plantilla plantilla.docx se genera con:

  dart run tool/gen_plantilla.dart

(desde la raíz del proyecto). Ya incluye los content controls necesarios.

Si quieres editarla en Word (modo Desarrollador), los Títulos usados son:

Texto simple:
  numero, fecha, cliente, ubicacion, tipoServicio, cantidadEquipos,
  tiempoEstimado, descripcion, total, subtitulo, validezDias

Tabla de servicios (table = "servicios"; en cada fila de datos):
  nombreServicio, descripcionServicio, precioServicio

Listas (list + item):
  listaIncluye / itemIncluye
  listaNoIncluye / itemNoIncluye
  listaNotas / itemNota

Ver documentación del paquete docx_template_fork para cómo insertar
controles de contenido en Word.
