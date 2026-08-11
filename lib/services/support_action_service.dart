import 'package:url_launcher/url_launcher.dart';

import '../models/appliance.dart';

class SupportActionException implements Exception {
  const SupportActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupportActionService {
  const SupportActionService();

  static Uri phoneUri(String phoneNumber) {
    final normalized = phoneNumber.trim().replaceAll(RegExp(r'[^0-9+*#]'), '');
    return Uri(scheme: 'tel', path: normalized);
  }

  static Uri emailUri(Appliance appliance) {
    final details = <String>[
      'Hello,',
      '',
      'I need support for the following appliance:',
      'Appliance: ${appliance.name}',
      if (appliance.brand.trim().isNotEmpty) 'Brand: ${appliance.brand}',
      if (appliance.modelNumber.trim().isNotEmpty)
        'Model: ${appliance.modelNumber}',
      if (appliance.serialNumber.trim().isNotEmpty)
        'Serial number: ${appliance.serialNumber}',
      '',
      'Issue:',
      '',
    ];

    final subject = 'Support request for ${appliance.name}';
    final body = details.join('\r\n');

    return Uri(
      scheme: 'mailto',
      path: appliance.supportEmail.trim(),
      query:
          'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
  }

  static Uri websiteUri(String website) {
    final trimmed = website.trim();
    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);

    const supportedSchemes = {'http', 'https'};
    if (uri == null ||
        !supportedSchemes.contains(uri.scheme.toLowerCase()) ||
        uri.host.trim().isEmpty ||
        uri.host.contains(' ') ||
        (!uri.host.contains('.') && uri.host != 'localhost')) {
      throw const FormatException('Invalid support website.');
    }

    return uri;
  }

  static bool isValidWebsite(String website) {
    if (website.trim().isEmpty) {
      return true;
    }

    try {
      websiteUri(website);
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> call(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) {
      throw const SupportActionException('No support phone number is saved.');
    }
    await _launch(
      phoneUri(phoneNumber),
      failureMessage: 'No phone app is available on this device.',
    );
  }

  Future<void> email(Appliance appliance) async {
    if (appliance.supportEmail.trim().isEmpty) {
      throw const SupportActionException('No support email is saved.');
    }
    await _launch(
      emailUri(appliance),
      failureMessage: 'No email app is available on this device.',
    );
  }

  Future<void> openWebsite(String website) async {
    if (website.trim().isEmpty) {
      throw const SupportActionException('No support website is saved.');
    }

    final Uri uri;
    try {
      uri = websiteUri(website);
    } on FormatException {
      throw const SupportActionException(
        'The saved support website is not valid.',
      );
    }

    await _launch(
      uri,
      failureMessage: 'The support website could not be opened.',
    );
  }

  Future<void> _launch(Uri uri, {required String failureMessage}) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw SupportActionException(failureMessage);
      }
    } on SupportActionException {
      rethrow;
    } catch (_) {
      throw SupportActionException(failureMessage);
    }
  }
}
