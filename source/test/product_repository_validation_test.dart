import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/product_repository.dart';
import 'package:shopmaster_pro/core/models/product.dart';

void main() {
  const validProduct = Product(
    name: 'Phone',
    purchaseRate: 100,
    saleRate: 150,
    gstRate: 18,
    openingStock: 5,
    minStock: 2,
  );

  group('ProductRepository product validation', () {
    test('accepts valid product details', () {
      expect(() => ProductRepository.validateProduct(validProduct), returnsNormally);
    });

    test('rejects blank item names', () {
      for (final name in ['', '   ', '\\n\\t']) {
        expect(
          () => ProductRepository.validateProduct(Product(name: name)),
          throwsArgumentError,
        );
      }
    });

    test('rejects non-finite and negative rates or stock levels', () {
      final invalidProducts = [
        const Product(name: 'Phone', purchaseRate: -1),
        const Product(name: 'Phone', saleRate: double.nan),
        const Product(name: 'Phone', openingStock: double.infinity),
        const Product(name: 'Phone', minStock: -0.5),
      ];
      for (final product in invalidProducts) {
        expect(() => ProductRepository.validateProduct(product), throwsArgumentError);
      }
    });

    test('rejects GST rates outside the supported percentage range', () {
      for (final rate in [-1, 101]) {
        expect(
          () => ProductRepository.validateProduct(Product(name: 'Phone', gstRate: rate)),
          throwsArgumentError,
        );
      }
    });

    test('requires an ID when validating an update', () {
      expect(
        () => ProductRepository.validateProduct(validProduct, requireId: true),
        throwsArgumentError,
      );
      expect(
        () => ProductRepository.validateProduct(
          const Product(id: 7, name: 'Phone'),
          requireId: true,
        ),
        returnsNormally,
      );
    });
  });
}
