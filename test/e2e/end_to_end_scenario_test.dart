import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/utils/csv_export_service.dart';
import 'package:splitmate/features/dashboard/domain/balance_service.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/settlements/data/settlements_repository.dart';
import 'package:splitmate/features/settlements/domain/settlement.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Milestone 6: Complete End-to-End Scenario with App Restart Verification', () async {
    final tempDir = Directory.systemTemp.createTempSync('splitmate_e2e_scenario');
    final dbPath = p.join(tempDir.path, 'splitmate_scenario.db');
    const balanceService = BalanceService();
    final selfId = DatabaseMigrations.defaultSelfUserId;

    try {
      // ---------------------------------------------------------
      // PHASE 1: Initial App Launch & Adding Contacts
      // ---------------------------------------------------------
      var appDb = await AppDatabase.open(
        path: dbPath,
        databaseFactory: databaseFactoryFfi,
      );
      var peopleRepo = SqlitePeopleRepository(appDb.database);
      var debtsRepo = SqliteDebtsRepository(appDb.database);
      var expensesRepo = SqliteExpensesRepository(appDb.database);
      var settlementsRepo = SqliteSettlementsRepository(appDb.database);

      // Verify self person exists
      final self = await peopleRepo.getSelfPerson();
      expect(self.name, 'You');
      expect(self.isSelf, isTrue);

      // Add two friends: Rahul and Priya
      final rahul = await peopleRepo.addPerson('Rahul');
      final priya = await peopleRepo.addPerson('Priya');
      expect(rahul.name, 'Rahul');
      expect(priya.name, 'Priya');

      // ---------------------------------------------------------
      // PHASE 2: Recording a Manual Debt (Rahul owes Blessy ₹100)
      // ---------------------------------------------------------
      final debt1 = await debtsRepo.createDebt(
        debtorId: rahul.id,
        creditorId: selfId,
        amountPaise: 10000, // ₹100.00
        debtDate: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Snacks and Tea',
      );
      expect(debt1.amountPaise, 10000);

      // Verify intermediate balances
      var debts = await debtsRepo.getAllDebts();
      var expenses = await expensesRepo.getAllExpenses();
      var settlements = await settlementsRepo.getAllSettlements();
      var people = await peopleRepo.getAllPeople();

      var summary = balanceService.computeDashboardSummary(
        selfId: selfId,
        people: people,
        debts: debts,
        expenses: expenses,
        settlements: settlements,
      );
      expect(summary.netBalancePaise, 10000); // +₹100
      expect(summary.youGetBackPaise, 10000);
      expect(summary.youOwePaise, 0);

      // ---------------------------------------------------------
      // PHASE 3: Recording Shared Expense (Blessy paid ₹150 for Dinner)
      // Split equally: Blessy ₹50, Rahul ₹50, Priya ₹50
      // ---------------------------------------------------------
      final expense1 = await expensesRepo.createExpense(
        title: 'Team Dinner',
        totalPaise: 15000, // ₹150.00
        payerId: selfId,
        splitType: 'equal',
        expenseDate: DateTime.now().subtract(const Duration(days: 1)),
        notes: 'Restaurant bill',
        shares: {
          selfId: 5000,
          rahul.id: 5000,
          priya.id: 5000,
        },
      );
      expect(expense1.shares.length, 3);

      // Check Rahul pairwise balance: ₹100 debt + ₹50 share = ₹150
      debts = await debtsRepo.getAllDebts();
      expenses = await expensesRepo.getAllExpenses();
      settlements = await settlementsRepo.getAllSettlements();

      var rahulBalance = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: rahul.id,
        debts: debts,
        expenses: expenses,
        settlements: settlements,
      );
      expect(rahulBalance, 15000); // Rahul owes Blessy ₹150.00

      // Check Priya pairwise balance: ₹50 share
      var priyaBalance = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: priya.id,
        debts: debts,
        expenses: expenses,
        settlements: settlements,
      );
      expect(priyaBalance, 5000); // Priya owes Blessy ₹50.00

      // ---------------------------------------------------------
      // PHASE 4: Recording a Partial Repayment (Rahul pays ₹60)
      // ---------------------------------------------------------
      final repayment1 = await settlementsRepo.createSettlement(
        payerId: rahul.id,
        receiverId: selfId,
        amountPaise: 6000, // ₹60.00
        settlementDate: DateTime.now(),
        notes: 'Partial payment via UPI',
      );
      expect(repayment1.amountPaise, 6000);

      // Verify balance right after partial repayment
      settlements = await settlementsRepo.getAllSettlements();
      rahulBalance = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: rahul.id,
        debts: debts,
        expenses: expenses,
        settlements: settlements,
      );
      expect(rahulBalance, 9000); // ₹150 - ₹60 = ₹90 remaining!

      // ---------------------------------------------------------
      // PHASE 5: Simulating App Close and Restart
      // ---------------------------------------------------------
      await appDb.close();

      // Reopen database at same file location
      appDb = await AppDatabase.open(
        path: dbPath,
        databaseFactory: databaseFactoryFfi,
      );
      peopleRepo = SqlitePeopleRepository(appDb.database);
      debtsRepo = SqliteDebtsRepository(appDb.database);
      expensesRepo = SqliteExpensesRepository(appDb.database);
      settlementsRepo = SqliteSettlementsRepository(appDb.database);

      // ---------------------------------------------------------
      // PHASE 6: Verifying Final Balances & Invariants Post-Restart
      // ---------------------------------------------------------
      final peopleAfter = await peopleRepo.getAllPeople();
      final debtsAfter = await debtsRepo.getAllDebts();
      final expensesAfter = await expensesRepo.getAllExpenses();
      final settlementsAfter = await settlementsRepo.getAllSettlements();

      // All records persisted correctly
      expect(peopleAfter.length, 3); // Blessy, Rahul, Priya
      expect(debtsAfter.length, 1);
      expect(expensesAfter.length, 1);
      expect(settlementsAfter.length, 1);

      // Pairwise balances
      final finalRahulBalance = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: rahul.id,
        debts: debtsAfter,
        expenses: expensesAfter,
        settlements: settlementsAfter,
      );
      expect(finalRahulBalance, 9000); // ₹90.00

      final finalPriyaBalance = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: priya.id,
        debts: debtsAfter,
        expenses: expensesAfter,
        settlements: settlementsAfter,
      );
      expect(finalPriyaBalance, 5000); // ₹50.00

      // Dashboard Summary: Blessy gets back ₹90 + ₹50 = ₹140.00
      final finalSummary = balanceService.computeDashboardSummary(
        selfId: selfId,
        people: peopleAfter,
        debts: debtsAfter,
        expenses: expensesAfter,
        settlements: settlementsAfter,
      );
      expect(finalSummary.netBalancePaise, 14000);
      expect(finalSummary.youGetBackPaise, 14000);
      expect(finalSummary.youOwePaise, 0);

      // Zero-Sum Invariant across all people
      final netBalances = balanceService.computeNetBalances(
        people: peopleAfter,
        debts: debtsAfter,
        expenses: expensesAfter,
        settlements: settlementsAfter,
      );
      expect(netBalances[selfId], 14000);
      expect(netBalances[rahul.id], -9000);
      expect(netBalances[priya.id], -5000);
      final netSum = netBalances.values.fold<int>(0, (a, b) => a + b);
      expect(netSum, 0); // Strict zero-sum invariant preserved!

      // Settlement Suggestions reconciliation
      final suggestions = SettlementEngine.computeSuggestions(
        netBalances: netBalances,
        people: peopleAfter,
      );
      expect(suggestions.length, 2);
      expect(suggestions.any((s) => s.fromPersonId == rahul.id && s.toPersonId == selfId && s.amountPaise == 9000), isTrue);
      expect(suggestions.any((s) => s.fromPersonId == priya.id && s.toPersonId == selfId && s.amountPaise == 5000), isTrue);

      // CSV Export test with persisted scenario
      final csv = CsvExportService.generateCsv(
        debts: debtsAfter,
        expenses: expensesAfter,
        settlements: settlementsAfter,
        people: peopleAfter,
      );
      final lines = csv.split('\r\n');
      expect(lines.length, 4); // 1 header + 3 transaction rows
      expect(csv, contains('Team Dinner'));
      expect(csv, contains('Snacks and Tea'));
      expect(csv, contains('Partial payment via UPI'));

      await appDb.close();
    } finally {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {
        // Windows file lock may briefly delay deletion until process exit
      }
    }
  });
}
