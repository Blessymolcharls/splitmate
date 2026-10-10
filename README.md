# SplitMate 💸

A polished, offline shared expense manager built with Flutter, Riverpod, and SQLite. SplitMate is specifically designed for people to keep track of bilateral debts, shared bills, and repayments without cloud dependencies or complex setup.

---

## ✨ Features

### 1. 👥 People & Contact Management
- **Personal Contact Directory**: Add, search, edit, and organize friends with avatar initials and live pairwise balances.
- **Identified Self Profile**: Clear "You" self profile that maintains a stable user ID across all historical records.
- **Detailed Person Ledger**: Inspect per-person transaction history, breakdown of "They Owe You" vs. "You Owe Them", and 1-tap "Settle Up".
- **Safe Archival**: Non-destructive archival of contacts with transaction history to preserve financial records.

### 2. 🤝 Direct Debt Tracking (IOUs)
- **Bilateral Debts**: Record simple debts (e.g., *"Blessy owes Anu ₹20.00"*) directly without creating artificial group expenses.
- **Live Preview**: Dynamic preview of debtor and creditor relationships before submission.
- **Form Validation**: Disallows self-debts, non-positive amounts, or missing participants.

### 3. 🧾 Shared Expenses & Splits
- **Flexible Bill Splitting**: Split group expenses equally or with custom amounts among selected participants.
- **Deterministic Equal Split**: Allocates fractional paise deterministically to ensure participants' shares sum exactly to the total bill without rounding discrepancies.
- **Live Custom Split Validation**: Shows real-time allocated and remaining amounts; prevents submission until shares match the bill total down to the paise.
- **Edit & Delete Protection**: Expense modifications recalculate all participant balances; deletions include safety confirmation dialogs.

### 4. 🔄 Repayments & Settlement Suggestions
- **Combined Ledger Netting**: Automatically aggregates manual debts, shared expenses, and prior repayments into net obligations.
- **Deterministic Settlement Engine**: Pure Dart greedy bipartite matching algorithm that computes the minimal number of transfers to reconcile all net balances to zero.
- **Overpayment & Wrong-Direction Protection**: Rejects payments exceeding outstanding debt or made in the reverse direction.
- **Pre-filled Repayment Forms**: 1-tap "Pay Full" or apply suggestions directly into the repayment form.
- **Non-Destructive History**: Repayments record standalone settlement entries without erasing or altering original expense records.

### 5. 📜 Chronological Activity & History
- **Unified Timeline**: View all debts, shared expenses, and debt settlements in a single chronological feed.
- **Multi-Filter Support**: Filter activity by transaction type (*All*, *Direct Debts*, *Expenses*, *Repayments*), by person, and by date range (*All Time*, *This Month*, *Last 30 Days*).
- **Repayment Details & Deletion**: Tap any repayment to view participants and notes, or safely delete it with a confirmation dialog.

### 6. 🔒 Data Privacy & Reliability
- **100% Offline & Local**: Built on SQLite with foreign key constraints (`PRAGMA foreign_keys = ON;`) and cascading deletes. No accounts, telemetry, or cloud sync.
- **App Restart Persistence**: Full transactional integrity verified across app closures and restarts.
- **CSV Data Export**: Export all transactions to RFC-4180 compliant CSV format with built-in preview, 1-tap clipboard copying, and local file saving.

### 7. 🎯 Financial Correctness
- **Strict Integer-Paise Arithmetic**: All financial values are stored and calculated as integer paise (`int`) to eliminate floating-point precision errors.
- **Zero-Sum Invariant**: Guaranteed zero-sum balance invariant across the combined ledger ($\sum_{i} \text{NetBalance}_i = 0$).

---

## 🏗️ Architecture & Tech Stack

```
splitmate/
├── lib/
│   ├── app/                      # Router (GoRouter), Theme (Material 3 Pastel)
│   ├── core/
│   │   ├── database/             # AppDatabase, SQLite migrations & foreign keys
│   │   ├── errors/               # Application & validation exception types
│   │   └── utils/                # MoneyFormatter (INR), MoneyParser, CsvExportService
│   ├── features/
│   │   ├── activity/             # Unified timeline & filtering
│   │   ├── dashboard/            # Net balance overview & quick action tiles
│   │   ├── debts/                # Manual debts (IOUs) repository, state & UI
│   │   ├── expenses/             # Shared expenses & split calculation
│   │   ├── people/               # People repository, profiles & detail ledgers
│   │   ├── settlements/          # Pure Dart settlement engine, repository & UI
│   │   └── settings/             # Preferences, SQLite info & CSV export
│   └── shared/widgets/           # AppScaffold, Navigation bar & quick add modal
└── test/                         # Unit, widget, and end-to-end integration tests
```

- **Framework**: [Flutter](https://flutter.dev) (Dart 3)
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod` AsyncNotifier)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router) (StatefulShellRoute with indexed stack)
- **Persistence**: [sqflite](https://pub.dev/packages/sqflite) (SQLite) + [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) for unit testing
- **Formatting**: [intl](https://pub.dev/packages/intl) (`en_IN` currency and date formatting)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.11.0 or newer)
- Android SDK / Android Studio (for Android deployment)
- Java 17+ (for Gradle builds)

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/bless/splitmate.git
cd splitmate
flutter pub get
```

### 2. Run the App
```bash
# Run on connected device or emulator
flutter run
```

### 3. Run Static Analysis
```bash
flutter analyze
```

### 4. Run the Test Suite
SplitMate has 79 automated tests covering business logic, repositories, widgets, and an end-to-end scenario test:
```bash
flutter test
```

### 5. Build Android Debug APK
```bash
flutter build apk --debug
```
The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-debug.apk`

---

## 🧪 Testing Verification

The project includes an end-to-end integration test (`test/e2e/end_to_end_scenario_test.dart`) verifying:
1. Adding contacts ("Blessy", "Rahul", "Priya").
2. Recording a manual debt (Rahul owes Blessy ₹100.00).
3. Recording an equally split expense (Dinner ₹150.00 $\to$ ₹50 each).
4. Recording a partial repayment (Rahul pays ₹60.00 $\to$ remaining debt ₹90.00).
5. Closing SQLite and re-opening the database (simulating app restart).
6. Verifying all final balances, zero-sum invariant ($\sum = 0$), settlement suggestions, and CSV export.

---

## 📄 License
This project is private and licensed for personal development and academic use.
