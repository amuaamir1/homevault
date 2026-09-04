import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('P15 CI/CD release hardening contracts', () {
    test('required workflows and P15 helper exist', () {
      for (final path in <String>[
        '.github/workflows/development-validation.yml',
        '.github/workflows/developer-release.yml',
        '.github/workflows/manual-release.yml',
        'scripts/ci/homevault_ci.py',
        'scripts/ci/Test-HomeVault-P15.ps1',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('all workflows use the repository Flutter version variable', () {
      for (final path in <String>[
        '.github/workflows/development-validation.yml',
        '.github/workflows/developer-release.yml',
        '.github/workflows/manual-release.yml',
      ]) {
        final workflow = read(path);
        expect(
          workflow,
          contains(r'flutter-version: ${{ vars.FLUTTER_VERSION }}'),
        );
        expect(workflow, contains('homevault_ci.py validate-ci'));
      }
      expect(read('scripts/ci/homevault_ci.py'), contains(r'^\d+\.\d+\.\d+$'));
    });

    test('dependency lock and source hygiene gates are wired in', () {
      final combined = <String>[
        read('.github/workflows/development-validation.yml'),
        read('.github/workflows/developer-release.yml'),
        read('.github/workflows/manual-release.yml'),
      ].join('\n');
      expect(combined, contains('validate-lock'));
      expect(combined, contains('P15 source safety gate'));
      expect(read('scripts/ci/homevault_ci.py'), contains('git", "ls-files'));
      expect(read('scripts/ci/homevault_ci.py'), contains('pubspec.lock'));
    });

    test('release workflows verify signatures before publishing', () {
      final developer = read('.github/workflows/developer-release.yml');
      final manual = read('.github/workflows/manual-release.yml');
      expect(developer, contains('--kind apk'));
      expect(manual, contains('--kind apk'));
      expect(manual, contains('--kind aab'));
      expect(manual, contains('flutter build appbundle'));
      expect(read('scripts/ci/homevault_ci.py'), contains('apksigner'));
      expect(read('scripts/ci/homevault_ci.py'), contains('jarsigner'));
    });

    test('integrity metadata and release notes are required', () {
      final combined =
          '${read('.github/workflows/developer-release.yml')}\n'
          '${read('.github/workflows/manual-release.yml')}';
      for (final token in <String>[
        'SHA256SUMS.txt',
        'release-manifest.json',
        'RELEASE_NOTES.md',
        'FINAL RELEASE GATE',
      ]) {
        expect(combined, contains(token), reason: token);
      }
    });

    test('publishing happens after the final release gate', () {
      for (final path in <String>[
        '.github/workflows/developer-release.yml',
        '.github/workflows/manual-release.yml',
      ]) {
        final workflow = read(path);
        final gate = workflow.indexOf('name: FINAL RELEASE GATE');
        final githubPublish = workflow.indexOf('name: Publish GitHub');
        final drivePublish = workflow.indexOf(
          'name: Upload release assets to Google Drive',
        );
        expect(gate, greaterThan(0), reason: path);
        expect(drivePublish, greaterThan(gate), reason: path);
        expect(githubPublish, greaterThan(gate), reason: path);
      }
    });

    test('failure diagnostics are privacy-safe by contract', () {
      final helper = read('scripts/ci/homevault_ci.py');
      final combined =
          '${read('.github/workflows/development-validation.yml')}\n'
          '${read('.github/workflows/developer-release.yml')}\n'
          '${read('.github/workflows/manual-release.yml')}';
      expect(combined, contains('P15 failure diagnostics'));
      expect(combined, contains('if: failure()'));
      expect(helper, isNot(contains('print(os.environ')));
    });

    test(
      'manual stable release supports AAB while developer stays APK focused',
      () {
        final developer = read('.github/workflows/developer-release.yml');
        final manual = read('.github/workflows/manual-release.yml');
        expect(developer, isNot(contains('flutter build appbundle')));
        expect(manual, contains(r'if: ${{ inputs.prerelease == false }}'));
        expect(manual, contains('app-release.aab'));
      },
    );
  });
}
