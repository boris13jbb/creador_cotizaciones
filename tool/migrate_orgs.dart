// Migración local / dry-run de cotizaciones legacy → organización.
// Uso:
//   dart run tool/migrate_orgs.dart --dry-run --uid=UID
//   dart run tool/migrate_orgs.dart --apply --uid=UID
//
// Nota: este script documenta el flujo. La ejecución contra producción
// requiere Application Default Credentials o ejecutarse vía Cloud Function.

void main(List<String> args) {
  final dryRun = !args.contains('--apply');
  String? uid;
  for (final a in args) {
    if (a.startsWith('--uid=')) uid = a.substring('--uid='.length);
  }

  // ignore: avoid_print
  print('CotiApp migración Fase 2');
  // ignore: avoid_print
  print('Modo: ${dryRun ? 'DRY-RUN (sin escrituras)' : 'APPLY'}');
  // ignore: avoid_print
  print('uid: ${uid ?? '(requerido)'}');
  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('Pasos que realiza la migración (ver docs/MIGRATION_FASE2.md):');
  // ignore: avoid_print
  print('1) Crear organizations/{orgId} + member owner + counters/quotes');
  // ignore: avoid_print
  print('2) Copiar users/{uid}/cotizaciones → organizations/{orgId}/quotes');
  // ignore: avoid_print
  print('3) Asignar sequence/number atómico y totalCents');
  // ignore: avoid_print
  print('4) Escribir users/{uid}.defaultOrganizationId');
  // ignore: avoid_print
  print('5) Dejar legacy intacto para rollback');
  // ignore: avoid_print
  print('');
  if (uid == null || uid.isEmpty) {
    // ignore: avoid_print
    print('ERROR: indica --uid=...');
    return;
  }
  if (dryRun) {
    // ignore: avoid_print
    print(
      'Dry-run OK. Para aplicar usa --apply (preferible vía Cloud Function).',
    );
  } else {
    // ignore: avoid_print
    print(
      'APPLY desde CLI local requiere credenciales Admin. '
      'Usa functions migrateUserToOrganization en producción.',
    );
  }
}
