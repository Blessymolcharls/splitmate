import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/features/dashboard/domain/balance_service.dart';
import 'package:splitmate/features/debts/domain/manual_debt.dart';
import 'package:splitmate/features/people/domain/person.dart';

void main() {
  group('BalanceService Domain Tests', () {
    const balanceService = BalanceService();

    final blessy = Person(
      id: DatabaseMigrations.defaultSelfUserId,
      name: 'Blessy',
      isSelf: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final anu = Person(
      id: 'anu-id',
      name: 'Anu',
      isSelf: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final rahul = Person(
      id: 'rahul-id',
      name: 'Rahul',
      isSelf: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final people = [blessy, anu, rahul];

    test('Blessy owes Anu ₹20: Blessy balance -2000 paise, Anu +2000 paise, sum is zero', () {
      final debt1 = ManualDebt(
        id: 'debt-1',
        debtorId: blessy.id,
        creditorId: anu.id,
        amountPaise: 2000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final balances = balanceService.computeNetBalances(
        people: people,
        debts: [debt1],
      );

      expect(balances[blessy.id], -2000);
      expect(balances[anu.id], 2000);
      expect(balances[rahul.id], 0);

      expect(balanceService.verifyZeroSumInvariant(balances), true);
    });

    test('Rahul owes Blessy ₹150: Rahul -15000 paise, Blessy +15000 paise, sum is zero', () {
      final debt2 = ManualDebt(
        id: 'debt-2',
        debtorId: rahul.id,
        creditorId: blessy.id,
        amountPaise: 15000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final balances = balanceService.computeNetBalances(
        people: people,
        debts: [debt2],
      );

      expect(balances[rahul.id], -15000);
      expect(balances[blessy.id], 15000);
      expect(balances[anu.id], 0);

      expect(balanceService.verifyZeroSumInvariant(balances), true);
    });

    test('Anu owes Rahul ₹200: Anu -20000 paise, Rahul +20000 paise, sum is zero', () {
      final debt3 = ManualDebt(
        id: 'debt-3',
        debtorId: anu.id,
        creditorId: rahul.id,
        amountPaise: 20000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final balances = balanceService.computeNetBalances(
        people: people,
        debts: [debt3],
      );

      expect(balances[anu.id], -20000);
      expect(balances[rahul.id], 20000);
      expect(balances[blessy.id], 0);

      expect(balanceService.verifyZeroSumInvariant(balances), true);
    });

    test('Combined sequence of manual debts preserves exact balances and zero-sum invariant', () {
      // 1. Blessy owes Anu ₹20
      final debt1 = ManualDebt(
        id: 'debt-1',
        debtorId: blessy.id,
        creditorId: anu.id,
        amountPaise: 2000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 2. Rahul owes Blessy ₹150
      final debt2 = ManualDebt(
        id: 'debt-2',
        debtorId: rahul.id,
        creditorId: blessy.id,
        amountPaise: 15000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Anu owes Rahul ₹200
      final debt3 = ManualDebt(
        id: 'debt-3',
        debtorId: anu.id,
        creditorId: rahul.id,
        amountPaise: 20000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final allDebts = [debt1, debt2, debt3];

      final balances = balanceService.computeNetBalances(
        people: people,
        debts: allDebts,
      );

      // Blessy: -2000 + 15000 = +13000 (+₹130)
      // Anu: +2000 - 20000 = -18000 (-₹180)
      // Rahul: -15000 + 20000 = +5000 (+₹50)
      expect(balances[blessy.id], 13000);
      expect(balances[anu.id], -18000);
      expect(balances[rahul.id], 5000);

      // Zero-sum invariant: 13000 + (-18000) + 5000 == 0
      expect(balanceService.verifyZeroSumInvariant(balances), true);

      // Check Dashboard Summary for Blessy
      final summary = balanceService.computeDashboardSummary(
        selfId: blessy.id,
        people: people,
        debts: allDebts,
      );

      // Rahul owes Blessy ₹150 -> You Get Back = ₹150 (15000 paise)
      // Blessy owes Anu ₹20 -> You Owe = ₹20 (2000 paise)
      // Net Balance = ₹150 - ₹20 = +₹130 (13000 paise)
      expect(summary.youGetBackPaise, 15000);
      expect(summary.youOwePaise, 2000);
      expect(summary.netBalancePaise, 13000);

      expect(summary.peopleWhoOweYou.length, 1);
      expect(summary.peopleWhoOweYou.first.person.id, rahul.id);
      expect(summary.peopleWhoOweYou.first.amountPaise, 15000);

      expect(summary.peopleYouOwe.length, 1);
      expect(summary.peopleYouOwe.first.person.id, anu.id);
      expect(summary.peopleYouOwe.first.amountPaise, 2000);
    });
  });
}
