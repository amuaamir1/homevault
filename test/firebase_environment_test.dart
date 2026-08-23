import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/firebase/homevault_firebase_environment.dart';

void main() {
  group('HomeVault Firebase environment guard', () {
    test('development accepts the dedicated development project', () {
      HomeVaultFirebaseEnvironmentConfig.validate(
        actualProjectId:
            HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
        environmentName: 'development',
        expectedProjectId:
            HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
        isReleaseMode: false,
        allowNonProductionRelease: false,
      );
    });

    test('release cannot silently use development Firebase', () {
      expect(
        () => HomeVaultFirebaseEnvironmentConfig.validate(
          actualProjectId:
              HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
          environmentName: 'development',
          expectedProjectId:
              HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
          isReleaseMode: true,
          allowNonProductionRelease: false,
        ),
        throwsA(isA<HomeVaultFirebaseEnvironmentException>()),
      );
    });

    test('explicit internal beta release can use development Firebase', () {
      HomeVaultFirebaseEnvironmentConfig.validate(
        actualProjectId:
            HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
        environmentName: 'development',
        expectedProjectId:
            HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
        isReleaseMode: true,
        allowNonProductionRelease: true,
      );
    });

    test('production requires a release build', () {
      expect(
        () => HomeVaultFirebaseEnvironmentConfig.validate(
          actualProjectId: 'homevault-production-example',
          environmentName: 'production',
          expectedProjectId: 'homevault-production-example',
          isReleaseMode: false,
          allowNonProductionRelease: false,
        ),
        throwsA(isA<HomeVaultFirebaseEnvironmentException>()),
      );
    });

    test('production rejects the development Firebase project', () {
      expect(
        () => HomeVaultFirebaseEnvironmentConfig.validate(
          actualProjectId:
              HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
          environmentName: 'production',
          expectedProjectId:
              HomeVaultFirebaseEnvironmentConfig.developmentProjectId,
          isReleaseMode: true,
          allowNonProductionRelease: false,
        ),
        throwsA(isA<HomeVaultFirebaseEnvironmentException>()),
      );
    });

    test('production requires an explicitly declared project id', () {
      expect(
        () => HomeVaultFirebaseEnvironmentConfig.validate(
          actualProjectId: 'homevault-production-example',
          environmentName: 'production',
          expectedProjectId: '',
          isReleaseMode: true,
          allowNonProductionRelease: false,
        ),
        throwsA(isA<HomeVaultFirebaseEnvironmentException>()),
      );
    });

    test('production accepts a matching non-development release project', () {
      HomeVaultFirebaseEnvironmentConfig.validate(
        actualProjectId: 'homevault-production-example',
        environmentName: 'prod',
        expectedProjectId: 'homevault-production-example',
        isReleaseMode: true,
        allowNonProductionRelease: false,
      );
    });

    test('expected and actual Firebase project ids must match', () {
      expect(
        () => HomeVaultFirebaseEnvironmentConfig.validate(
          actualProjectId: 'homevault-production-a',
          environmentName: 'production',
          expectedProjectId: 'homevault-production-b',
          isReleaseMode: true,
          allowNonProductionRelease: false,
        ),
        throwsA(isA<HomeVaultFirebaseEnvironmentException>()),
      );
    });
  });
}
