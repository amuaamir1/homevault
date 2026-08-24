import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/accessibility/homevault_accessibility.dart';

void main() {
  test('metric layout expands as text scaling increases', () {
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 720,
        textScale: 1,
      ),
      4,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 390,
        textScale: 1,
      ),
      2,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 720,
        textScale: 1.4,
      ),
      2,
    );
    expect(
      HomeVaultAccessibility.responsiveColumnCount(
        availableWidth: 390,
        textScale: 2,
      ),
      1,
    );
  });

  test('count labels include both meaning and value', () {
    expect(HomeVaultAccessibility.countLabel('Documents', 4), 'Documents: 4');
  });
}
