import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/party_repository.dart';
import 'package:shopmaster_pro/core/models/party.dart';

void main() {
  group('PartyRepository party validation', () {
    test('accepts valid customer and supplier records', () {
      expect(() => PartyRepository.validateParty(const Party(
        type: PartyType.customer, name: 'Walk-in customer',
        openingBalance: -250, currentBalance: -250,
      )), returnsNormally);
      expect(() => PartyRepository.validateParty(const Party(
        id: 5, type: PartyType.supplier, name: 'Supplier Ltd',
      ), requireId: true), returnsNormally);
    });

    test('rejects blank names, non-finite balances and missing update IDs', () {
      expect(() => PartyRepository.validateParty(const Party(
        type: PartyType.customer, name: '  ',
      )), throwsArgumentError);
      expect(() => PartyRepository.validateParty(const Party(
        type: PartyType.customer, name: 'Customer', openingBalance: double.nan,
      )), throwsArgumentError);
      expect(() => PartyRepository.validateParty(const Party(
        type: PartyType.customer, name: 'Customer', currentBalance: double.infinity,
      )), throwsArgumentError);
      expect(() => PartyRepository.validateParty(const Party(
        type: PartyType.customer, name: 'Customer',
      ), requireId: true), throwsArgumentError);
    });
  });

  group('PartyRepository payment validation', () {
    test('accepts a valid receipt/payment', () {
      expect(() => PartyRepository.validatePayment(
        partyId: 3, amount: 1200.50, accountId: 1,
        payMode: 'UPI', date: '2026-11-26',
      ), returnsNormally);
    });

    test('rejects invalid IDs, amounts, payment mode and dates', () {
      expect(() => PartyRepository.validatePayment(
        partyId: 0, amount: 10, accountId: 1,
        payMode: 'Cash', date: '2026-11-26',
      ), throwsArgumentError);
      expect(() => PartyRepository.validatePayment(
        partyId: 1, amount: 10, accountId: -1,
        payMode: 'Cash', date: '2026-11-26',
      ), throwsArgumentError);
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => PartyRepository.validatePayment(
          partyId: 1, amount: amount, accountId: 1,
          payMode: 'Cash', date: '2026-11-26',
        ), throwsArgumentError);
      }
      expect(() => PartyRepository.validatePayment(
        partyId: 1, amount: 10, accountId: 1,
        payMode: '  ', date: '2026-11-26',
      ), throwsArgumentError);
      for (final date in ['2026-02-30', '26-11-2026', '']) {
        expect(() => PartyRepository.validatePayment(
          partyId: 1, amount: 10, accountId: 1,
          payMode: 'Cash', date: date,
        ), throwsArgumentError);
      }
    });
  });
}
