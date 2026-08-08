import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';

void main() {
  group('Warranty calculation', () {
    test('calculates warranty expiry from years', () {
      final expiry = Appliance.calculateWarrantyExpiryDate(
        startDate: DateTime(2026, 8, 8),
        durationValue: 2,
        durationUnit: WarrantyDurationUnit.years,
      );

      expect(expiry, DateTime(2028, 8, 7));
    });

    test('three-year warranty from 1 Aug 2024 expires 31 Jul 2027', () {
      final expiry = Appliance.calculateWarrantyExpiryDate(
        startDate: DateTime(2024, 8, 1),
        durationValue: 3,
        durationUnit: WarrantyDurationUnit.years,
      );

      expect(expiry, DateTime(2027, 7, 31));
    });

    test('calculates warranty expiry from months', () {
      final expiry = Appliance.calculateWarrantyExpiryDate(
        startDate: DateTime(2026, 8, 8),
        durationValue: 18,
        durationUnit: WarrantyDurationUnit.months,
      );

      expect(expiry, DateTime(2028, 2, 7));
    });

    test('handles end-of-month warranty starts', () {
      final expiry = Appliance.calculateWarrantyExpiryDate(
        startDate: DateTime(2026, 1, 31),
        durationValue: 1,
        durationUnit: WarrantyDurationUnit.months,
      );

      expect(expiry, DateTime(2026, 2, 28));
    });

    test('handles leap-day warranty starts', () {
      final expiry = Appliance.calculateWarrantyExpiryDate(
        startDate: DateTime(2024, 2, 29),
        durationValue: 1,
        durationUnit: WarrantyDurationUnit.years,
      );

      expect(expiry, DateTime(2025, 2, 28));
    });

    test('duration metadata survives JSON round trip', () {
      final original = Appliance(
        id: 'appliance-1',
        name: 'Refrigerator',
        category: 'Kitchen Appliance',
        brand: 'LG',
        purchaseDate: DateTime(2026, 8, 8),
        warrantyExpiryDate: DateTime(2028, 8, 7),
        warrantyDurationValue: 2,
        warrantyDurationUnit: WarrantyDurationUnit.years,
        createdAt: DateTime(2026, 8, 8),
      );

      final restored = Appliance.fromJson(original.toJson());

      expect(restored.warrantyDurationValue, 2);
      expect(restored.warrantyDurationUnit, WarrantyDurationUnit.years);
      expect(restored.warrantyDurationLabel, '2 years');
      expect(restored.warrantyExpiryDate, DateTime(2028, 8, 7));
    });

    test('legacy warranty records remain compatible', () {
      final restored = Appliance.fromJson({
        'id': 'legacy-1',
        'name': 'Television',
        'category': 'Television',
        'brand': 'Samsung',
        'purchaseDate': '2025-08-08T00:00:00.000',
        'warrantyExpiryDate': '2026-08-07T00:00:00.000',
        'createdAt': '2025-08-08T00:00:00.000',
      });

      expect(restored.warrantyDurationValue, isNull);
      expect(restored.warrantyDurationUnit, isNull);
      expect(restored.warrantyDurationLabel, isEmpty);
      expect(restored.warrantyExpiryDate, DateTime(2026, 8, 7));
    });
  });
}
