import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/debts/presentation/add_debt_screen.dart';
import '../features/expenses/presentation/add_expense_screen.dart';
import '../features/people/presentation/people_screen.dart';
import '../features/people/presentation/person_detail_screen.dart';
import '../features/settlements/presentation/record_repayment_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/people',
                builder: (context, state) => const PeopleScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final personId = state.pathParameters['id'] ?? '';
                      return PersonDetailScreen(personId: personId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/debts/add',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final debtId = state.uri.queryParameters['debtId'];
          final debtorId = state.uri.queryParameters['debtorId'];
          final creditorId = state.uri.queryParameters['creditorId'];
          return AddDebtScreen(
            debtId: debtId,
            prefilledDebtorId: debtorId,
            prefilledCreditorId: creditorId,
          );
        },
      ),
      GoRoute(
        path: '/expenses/add',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final expenseId = state.uri.queryParameters['expenseId'];
          return AddExpenseScreen(expenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/settlements/add',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final debtor = state.uri.queryParameters['debtorId'];
          final creditor = state.uri.queryParameters['creditorId'];
          final amount = state.uri.queryParameters['amountPaise'] != null
              ? int.tryParse(state.uri.queryParameters['amountPaise']!)
              : null;
          return RecordRepaymentScreen(
            prefilledDebtorId: debtor,
            prefilledCreditorId: creditor,
            prefilledAmountPaise: amount,
          );
        },
      ),
    ],
  );

  ref.onDispose(() => router.dispose());
  return router;
});
