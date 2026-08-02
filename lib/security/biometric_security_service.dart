import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricDeviceStatus {
  const BiometricDeviceStatus({
    required this.isAvailable,
    required this.label,
    this.message,
  });

  final bool isAvailable;
  final String label;
  final String? message;
}

class BiometricAuthenticationResult {
  const BiometricAuthenticationResult({
    required this.authenticated,
    this.wasCanceled = false,
    this.message,
  });

  final bool authenticated;
  final bool wasCanceled;
  final String? message;
}

class BiometricSecurityService {
  BiometricSecurityService({
    LocalAuthentication? localAuthentication,
    FlutterSecureStorage? storage,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  static const _enabledKey = 'homevault.biometric.enabled.v1';

  final LocalAuthentication _localAuthentication;
  final FlutterSecureStorage _storage;

  Future<bool> isEnabled() async {
    return await _storage.read(key: _enabledKey) == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _storage.write(key: _enabledKey, value: 'true');
    } else {
      await _storage.delete(key: _enabledKey);
    }
  }

  Future<BiometricDeviceStatus> getDeviceStatus() async {
    try {
      final canCheck = await _localAuthentication.canCheckBiometrics;
      if (!canCheck) {
        return const BiometricDeviceStatus(
          isAvailable: false,
          label: 'biometric unlock',
          message: 'This device does not support biometric authentication.',
        );
      }

      final available = await _localAuthentication.getAvailableBiometrics();
      if (available.isEmpty) {
        return const BiometricDeviceStatus(
          isAvailable: false,
          label: 'biometric unlock',
          message:
              'No fingerprint or face unlock is enrolled in Android settings.',
        );
      }

      return BiometricDeviceStatus(
        isAvailable: true,
        label: _labelFor(available),
      );
    } on LocalAuthException catch (error) {
      return BiometricDeviceStatus(
        isAvailable: false,
        label: 'biometric unlock',
        message: _messageFor(error),
      );
    } catch (_) {
      return const BiometricDeviceStatus(
        isAvailable: false,
        label: 'biometric unlock',
        message: 'Biometric authentication is currently unavailable.',
      );
    }
  }

  Future<BiometricAuthenticationResult> authenticate() async {
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Use biometrics to unlock HomeVault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      return BiometricAuthenticationResult(
        authenticated: authenticated,
        wasCanceled: !authenticated,
      );
    } on LocalAuthException catch (error) {
      final canceled =
          error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled ||
          error.code == LocalAuthExceptionCode.userRequestedFallback;

      return BiometricAuthenticationResult(
        authenticated: false,
        wasCanceled: canceled,
        message: canceled ? null : _messageFor(error),
      );
    } catch (_) {
      return const BiometricAuthenticationResult(
        authenticated: false,
        message: 'Biometric authentication failed. Use your HomeVault PIN.',
      );
    }
  }

  static String _labelFor(List<BiometricType> types) {
    final hasFingerprint = types.contains(BiometricType.fingerprint);
    final hasFace = types.contains(BiometricType.face);

    if (hasFingerprint && hasFace) return 'fingerprint or face unlock';
    if (hasFingerprint) return 'fingerprint';
    if (hasFace) return 'face unlock';
    return 'biometric unlock';
  }

  static String _messageFor(LocalAuthException error) {
    return switch (error.code) {
      LocalAuthExceptionCode.noBiometricsEnrolled =>
        'No fingerprint or face unlock is enrolled in Android settings.',
      LocalAuthExceptionCode.noBiometricHardware =>
        'This device does not support biometric authentication.',
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
        'Biometric hardware is temporarily unavailable.',
      LocalAuthExceptionCode.temporaryLockout =>
        'Biometrics are temporarily locked. Wait or use your HomeVault PIN.',
      LocalAuthExceptionCode.biometricLockout =>
        'Biometrics are locked. Unlock the phone once, then try again.',
      LocalAuthExceptionCode.noCredentialsSet =>
        'Set up a screen lock and biometrics in Android settings first.',
      LocalAuthExceptionCode.authInProgress =>
        'A biometric request is already in progress.',
      LocalAuthExceptionCode.uiUnavailable =>
        'The biometric prompt could not be displayed.',
      LocalAuthExceptionCode.timeout =>
        'Biometric verification timed out. Try again.',
      _ =>
        error.description ??
            'Biometric authentication failed. Use your HomeVault PIN.',
    };
  }
}
