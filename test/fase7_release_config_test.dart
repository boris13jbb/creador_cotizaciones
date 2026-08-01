import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regresión ligera de artefactos de publicación (Fase 7).
void main() {
  test('pubspec version semver+build', () {
    final text = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(text);
    expect(match, isNotNull);
    expect(match!.group(1), matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
  });

  test('PWA manifest brand CotiApp', () {
    final json = File('web/manifest.json').readAsStringSync();
    expect(json, contains('"name": "CotiApp"'));
    expect(json, contains('"short_name": "CotiApp"'));
    expect(json, isNot(contains('A new Flutter project')));
  });

  test('docs de producción existen', () {
    for (final path in [
      'docs/PRODUCTION_CHECKLIST.md',
      'docs/BACKUP_ROLLBACK.md',
      'docs/RELEASE_ANDROID.md',
      'docs/USER_GUIDE.md',
      'docs/DEPLOY_WEB.md',
      'android/key.properties.example',
      '.github/workflows/release.yml',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('firebase.json declara hosting hacia build/web', () {
    final json = File('firebase.json').readAsStringSync();
    expect(json, contains('"public": "build/web"'));
    expect(json, contains('"hosting"'));
  });
}
