import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P19 Phase 4 uses accessible stable color tokens', () {
    final colors = File('lib/theme/app_colors.dart').readAsStringSync();

    expect(colors, contains('secondary = Color(0xFF0069A8)'));
    expect(colors, contains('success = Color(0xFF1B5E20)'));
    expect(colors, contains('warning = Color(0xFF8A5D00)'));
    expect(colors, contains('danger = Color(0xFFB71C1C)'));
    expect(colors, contains('textSecondary = Color(0xFF616161)'));

    expect(colors, isNot(contains('Color(0xFF42A5F5)')));
    expect(colors, isNot(contains('Color(0xFFF9A825)')));
    expect(colors, isNot(contains('Color(0xFF757575)')));
  });

  test('high-density summary surfaces use text-scale responsive wrapping', () {
    final reports = File(
      'lib/screens/reports/reports_screen.dart',
    ).readAsStringSync();
    final documents = File(
      'lib/screens/documents/documents_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/screens/service/service_center_screen.dart',
    ).readAsStringSync();
    final warranty = File(
      'lib/screens/warranty/warranty_screen.dart',
    ).readAsStringSync();
    final reminders = File(
      'lib/screens/reminders/reminder_center_screen.dart',
    ).readAsStringSync();

    expect(reports, contains('HomeVaultAccessibility.responsiveColumnCount'));
    expect(reports, contains('maxColumns: 4'));
    expect(reports, isNot(contains('height: 92')));
    expect(reports, isNot(contains('overflow: TextOverflow.ellipsis')));

    expect(documents, contains('HomeVaultAccessibility.responsiveColumnCount'));
    expect(documents, contains('maxColumns: 3'));

    expect(service, contains('HomeVaultAccessibility.responsiveColumnCount'));
    expect(service, contains('maxColumns: 3'));

    expect(warranty, contains('return Wrap('));
    expect(reminders, contains('for (final item in items)'));
  });

  test('essential report and reminder labels are not force-truncated', () {
    final reportBar = File('lib/widgets/report_bar.dart').readAsStringSync();
    final reminders = File(
      'lib/screens/reminders/reminder_center_screen.dart',
    ).readAsStringSync();

    expect(reportBar, isNot(contains('TextOverflow.ellipsis')));
    expect(
      reminders,
      isNot(
        contains(
          'reminder.applianceName,\n'
          '                            maxLines: 1,\n'
          '                            overflow: TextOverflow.ellipsis',
        ),
      ),
    );
  });

  test('large-text status components avoid rigid horizontal-only layout', () {
    final reportBar = File('lib/widgets/report_bar.dart').readAsStringSync();
    final warrantyChip = File(
      'lib/widgets/warranty_status_chip.dart',
    ).readAsStringSync();

    expect(reportBar, contains('final stackHeader ='));
    expect(reportBar, contains('textScale >= 1.3'));
    expect(reportBar, contains('constraints.maxWidth < 320'));

    expect(warrantyChip, contains('child: Wrap('));
    expect(warrantyChip, contains("label: 'Warranty status: \$label'"));
    expect(warrantyChip, isNot(contains('mainAxisSize: MainAxisSize.min')));
  });

  test('contrast helpers support reproducible Phase 4 audit checks', () {
    final accessibility = File(
      'lib/accessibility/homevault_accessibility.dart',
    ).readAsStringSync();

    expect(accessibility, contains('static double contrastRatio('));
    expect(accessibility, contains('static Color blendOver('));
    expect(accessibility, contains('int maxColumns = 4'));
  });
}
