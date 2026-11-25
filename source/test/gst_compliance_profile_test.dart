import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/settings_repository.dart';

void main() {
  group('GST compliance profile preferences', () {
    test('round trips registration type and return frequency', () {
      const settings = ShopSettings(
        gstin: '19ABCDE1234F1Z5',
        gstRegistrationType: 'regular',
        gstReturnFrequency: 'quarterly',
      );

      final restored = ShopSettings.fromMap(settings.toMap());

      expect(restored.gstin, settings.gstin);
      expect(restored.gstRegistrationType, 'regular');
      expect(restored.gstReturnFrequency, 'quarterly');
    });

    test('older saved settings use safe GST defaults', () {
      final restored = ShopSettings.fromMap({
        'shop_name': 'Old Shop',
        'gstin': '',
      });

      expect(restored.gstRegistrationType, 'not_registered');
      expect(restored.gstReturnFrequency, 'monthly');
    });

    test('copyWith preserves GST preferences unless changed', () {
      const settings = ShopSettings(
        gstRegistrationType: 'composition',
        gstReturnFrequency: 'quarterly',
      );

      final restored = settings.copyWith(shopName: 'Updated Shop');

      expect(restored.gstRegistrationType, 'composition');
      expect(restored.gstReturnFrequency, 'quarterly');
    });
  });
}
