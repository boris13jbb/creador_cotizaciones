import 'package:creador_cotizaciones/saas/services/client_csv_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsea CSV de clientes con cabecera EN', () {
    const csv = '''
name,email,phone,identification
Acme SA,a@acme.com,0999,RUC1
Beta Ltd,bad-email,111,RUC2
,skip@x.com,1,x
Gamma,g@g.com,,
''';
    final r = ClientCsvImportService.instance.parse(
      csv: csv,
      organizationId: 'org1',
    );
    expect(r.okCount, 2); // Acme + Gamma (Beta email inválido)
    expect(r.toUpsert.first.name, 'Acme SA');
    expect(r.toUpsert.first.email, 'a@acme.com');
    expect(r.errors, isNotEmpty);
    expect(r.skippedEmpty, 1);
  });

  test('acepta cabeceras en español', () {
    const csv = 'nombre,correo,telefono\nCliente Uno,uno@x.com,555\n';
    final r = ClientCsvImportService.instance.parse(
      csv: csv,
      organizationId: 'org',
    );
    expect(r.okCount, 1);
    expect(r.toUpsert.single.phone, '555');
  });
}
