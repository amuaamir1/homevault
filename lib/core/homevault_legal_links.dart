class HomeVaultLegalLinks {
  const HomeVaultLegalLinks._();

  static const String privacyPolicyUrl = String.fromEnvironment(
    'HOMEVAULT_PRIVACY_POLICY_URL',
  );
  static const String termsOfServiceUrl = String.fromEnvironment(
    'HOMEVAULT_TERMS_OF_SERVICE_URL',
  );
  static const String accountDeletionUrl = String.fromEnvironment(
    'HOMEVAULT_ACCOUNT_DELETION_URL',
  );
  static const String supportEmail = String.fromEnvironment(
    'HOMEVAULT_SUPPORT_EMAIL',
  );

  static Uri? get privacyPolicyUri => _httpsUri(privacyPolicyUrl);
  static Uri? get termsOfServiceUri => _httpsUri(termsOfServiceUrl);
  static Uri? get accountDeletionUri => _httpsUri(accountDeletionUrl);

  static Uri? get supportEmailUri {
    final email = supportEmail.trim();
    if (!_looksLikeEmail(email)) return null;

    return Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: const {'subject': 'HomeVault support'},
    );
  }

  static bool get hasProductionLegalLinks =>
      privacyPolicyUri != null &&
      termsOfServiceUri != null &&
      accountDeletionUri != null &&
      supportEmailUri != null;

  static Uri? _httpsUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty ||
        _isUnsafeHost(uri.host)) {
      return null;
    }

    return uri;
  }

  static bool _isUnsafeHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '0.0.0.0' ||
        normalized.endsWith('.local');
  }

  static bool _looksLikeEmail(String value) {
    if (value.isEmpty || value.contains(RegExp(r'\s'))) return false;

    final at = value.indexOf('@');
    if (at <= 0 || at != value.lastIndexOf('@')) return false;

    final domain = value.substring(at + 1);
    return domain.contains('.') &&
        !domain.startsWith('.') &&
        !domain.endsWith('.');
  }
}
