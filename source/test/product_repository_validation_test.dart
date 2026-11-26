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

  group('ProductRepository stock adjustment validation', () {
    test('accepts a valid stock movement and returns resulting stock', () {
      expect(
        ProductRepository.validateStockAdjustment(
          productId: 4,
          currentStock: 10,
          change: -2.5,
          reason: 'Sales return correction',
          expectedCurrentStock: 10,
        ),
        7.5,
      );
    });

    test('rejects invalid item IDs, quantities, reasons and expected stock', () {
      final invalid = [
        () => ProductRepository.validateStockAdjustment(productId: 0, currentStock: 2, change: 1, reason: 'Count'),
        () => ProductRepository.validateStockAdjustment(productId: 1, currentStock: 2, change: 0, reason: 'Count'),
        () => ProductRepository.validateStockAdjustment(productId: 1, currentStock: 2, change: double.nan, reason: 'Count'),
        () => ProductRepository.validateStockAdjustment(productId: 1, currentStock: 2, change: 1, reason: '  '),
        () => ProductRepository.validateStockAdjustment(productId: 1, currentStock: double.infinity, change: 1, reason: 'Count'),
        () => ProductRepository.validateStockAdjustment(productId: 1, currentStock: 2, change: 1, reason: 'Count', expectedCurrentStock: double.nan),
      ];
      for (final validate in invalid) {
        expect(validate, throwsArgumentError);
      }
    });

    test('rejects arithmetic overflow in the resulting stock', () {
      expect(
        () => ProductRepository.validateStockAdjustment(
          productId: 1,
          currentStock: double.maxFinite,
          change: double.maxFinite,
          reason: 'Stock count',
        ),
        throwsArgumentError,
      );
    });
  });

  group('ProductRepository product validation', () {
    test('accepts valid product details', () {
      expect(() => ProductRepository.validateProduct(validProduct), returnsNormally);
    });

    test('rejects blank item names', () {
      for (final name in ['', '   ', '\n\t']) {
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
