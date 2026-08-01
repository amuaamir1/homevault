import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/support_action_service.dart';

void main() {
  test('phone URI removes visual separators but keeps the country code', () {
    final uri = SupportActionService.phoneUri('+966 11-123 4567');

    expect(uri.scheme, 'tel');
    expect(uri.path, '+966111234567');
  });

  test('email URI contains appliance details for the support request', () {
    final appliance = Appliance(
      id: 'ac-1',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      modelNumber: 'FTKM50',
      serialNumber: 'SN-100',
      supportEmail: 'care@example.com',
      createdAt: DateTime(2026, 8, 1),
    );

    final uri = SupportActionService.emailUri(appliance);

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'care@example.com');
    expect(
      uri.queryParameters['subject'],
      'Support request for Living room AC',
    );
    expect(uri.queryParameters['body'], contains('Brand: Daikin'));
    expect(uri.queryParameters['body'], contains('Model: FTKM50'));
    expect(uri.queryParameters['body'], contains('Serial number: SN-100'));
  });

  test('website URI adds HTTPS when the scheme is omitted', () {
    final uri = SupportActionService.websiteUri('support.example.com/help');

    expect(uri.scheme, 'https');
    expect(uri.host, 'support.example.com');
    expect(uri.path, '/help');
  });

  test('invalid support websites are rejected', () {
    expect(SupportActionService.isValidWebsite('support.example.com'), isTrue);
    expect(SupportActionService.isValidWebsite('not a website'), isFalse);
  });
}
