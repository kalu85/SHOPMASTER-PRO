import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/models/app_module.dart';
import 'package:shopmaster_pro/core/models/product.dart';
import 'package:shopmaster_pro/core/utils/validators.dart';
import 'package:shopmaster_pro/main.dart';

void main() {
  test('all 16 modules including the shop owner guide are registered', () {
    expect(appModules.length, 16);
    expect(appModules.map((m) => m.id).toSet().length, 16);
  });

  group('Product stock status', () {
    test('negative stock is flagged', () {
      const p = Product(name: 'A', currentStock: -2, minStock: 5);
      expect(p.isNegative, isTrue);
      expect(p.isLow, isFalse);
    });

    test('low stock is flagged at or below minimum', () {
      const p = Product(name: 'A', currentStock: 3, minStock: 5);
      expect(p.isLow, isTrue);
      expect(p.isNegative, isFalse);
    });

    test('service items never show stock alerts', () {
      const p = Product(
        name: 'Repair',
        currentStock: -1,
        minStock: 5,
        isService: true,
      );
      expect(p.isNegative, isFalse);
      expect(p.isLow, isFalse);
    });
  });

  group('Validators', () {
    test('GSTIN', () {
      expect(Validators.isValidGstin('27AAPFU0939F1ZV'), isTrue);
      expect(Validators.isValidGstin('27aapfu0939f1zv'), isTrue);
      expect(Validators.isValidGstin('12345'), isFalse);
    });

    test('phone and email', () {
      expect(Validators.isValidPhone('9876543210'), isTrue);
      expect(Validators.isValidPhone('abc'), isFalse);
      expect(Validators.isValidEmail('shop@example.com'), isTrue);
      expect(Validators.isValidEmail('shop@'), isFalse);
    });
  });

  testWidgets('app starts on the dashboard', (tester) async {
    await tester.pumpWidget(const ShopMasterApp(bypassAppLock: true));
    expect(find.text('SHOPMASTER PRO'), findsWidgets);
    expect(find.text("Today's Sales"), findsOneWidget);
  });
}
