import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/theme/app_theme.dart';
import 'package:homevault/widgets/report_bar.dart';
import 'package:homevault/widgets/warranty_status_chip.dart';
import 'package:homevault/models/appliance.dart';

void main() {
  for (final scale in <double>[1.0, 1.3, 1.7, 2.0]) {
    testWidgets(
      'report/status surfaces reflow without overflow at scale $scale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 320,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReportBar(
                            label:
                                'Appliances with service records requiring attention',
                            value: 128,
                            total: 250,
                            trailing: '₹12,34,567/-',
                          ),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              WarrantyStatusChip(status: WarrantyStatus.active),
                              WarrantyStatusChip(
                                status: WarrantyStatus.expiringSoon,
                              ),
                              WarrantyStatusChip(
                                status: WarrantyStatus.expired,
                              ),
                              WarrantyStatusChip(
                                status: WarrantyStatus.notProvided,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.text('Appliances with service records requiring attention'),
          findsOneWidget,
        );
        expect(find.text('Expiring soon'), findsOneWidget);
      },
    );
  }
}
