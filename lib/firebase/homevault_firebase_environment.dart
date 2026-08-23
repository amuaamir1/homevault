import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum HomeVaultFirebaseEnvironment { development, production }

class HomeVaultFirebaseEnvironmentException implements Exception {
  const HomeVaultFirebaseEnvironmentException(this.code);

  final String code;

  @override
  String toString() =>
      'HomeVault Firebase environment configuration is invalid ($code).';
}

class HomeVaultFirebaseEnvironmentConfig {
  const HomeVaultFirebaseEnvironmentConfig._();

  static const String developmentProjectId = 'homevault-aamir-india-1701';

  static const String _environmentName = String.fromEnvironment(
    'HOMEVAULT_ENV',
    defaultValue: 'development',
  );

  static const String _expectedProjectId = String.fromEnvironment(
    'HOMEVAULT_FIREBASE_PROJECT_ID',
  );

  static const bool _allowNonProductionRelease = bool.fromEnvironment(
    'HOMEVAULT_ALLOW_NON_PROD_RELEASE',
    defaultValue: false,
  );

  static HomeVaultFirebaseEnvironment get current =>
      parseEnvironment(_environmentName);

  static void validateFirebaseOptions(FirebaseOptions options) {
    validate(
      actualProjectId: options.projectId,
      environmentName: _environmentName,
      expectedProjectId: _expectedProjectId,
      isReleaseMode: kReleaseMode,
      allowNonProductionRelease: _allowNonProductionRelease,
    );
  }

  @visibleForTesting
  static HomeVaultFirebaseEnvironment parseEnvironment(String value) {
    switch (value.trim().toLowerCase()) {
      case 'development':
      case 'dev':
        return HomeVaultFirebaseEnvironment.development;
      case 'production':
      case 'prod':
        return HomeVaultFirebaseEnvironment.production;
      default:
        throw const HomeVaultFirebaseEnvironmentException(
          'unknown-environment',
        );
    }
  }

  @visibleForTesting
  static void validate({
    required String actualProjectId,
    required String environmentName,
    required String expectedProjectId,
    required bool isReleaseMode,
    required bool allowNonProductionRelease,
  }) {
    final environment = parseEnvironment(environmentName);
    final actual = actualProjectId.trim();
    final expected = expectedProjectId.trim();

    if (actual.isEmpty) {
      throw const HomeVaultFirebaseEnvironmentException(
        'missing-actual-project-id',
      );
    }

    if (expected.isNotEmpty && expected != actual) {
      throw const HomeVaultFirebaseEnvironmentException('project-id-mismatch');
    }

    switch (environment) {
      case HomeVaultFirebaseEnvironment.development:
        if (actual != developmentProjectId) {
          throw const HomeVaultFirebaseEnvironmentException(
            'development-project-mismatch',
          );
        }
        if (isReleaseMode && !allowNonProductionRelease) {
          throw const HomeVaultFirebaseEnvironmentException(
            'development-release-not-explicitly-allowed',
          );
        }
        break;
      case HomeVaultFirebaseEnvironment.production:
        if (!isReleaseMode) {
          throw const HomeVaultFirebaseEnvironmentException(
            'production-requires-release-build',
          );
        }
        if (expected.isEmpty) {
          throw const HomeVaultFirebaseEnvironmentException(
            'production-project-id-not-declared',
          );
        }
        if (actual == developmentProjectId) {
          throw const HomeVaultFirebaseEnvironmentException(
            'production-cannot-use-development-project',
          );
        }
        break;
    }
  }
}
