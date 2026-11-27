import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/services/database/profession_service.dart';
import 'package:flutter_test/flutter_test.dart';

Profession _profession(
  String id, {
  String? parentId,
  bool? isActive = true,
}) {
  final date = DateTime(2026, 1, 1);
  return Profession(
    id: id,
    name: id,
    categories: const [],
    parentId: parentId,
    isActive: isActive,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test('deleting a profession includes all nested seasons', () {
    final professions = [
      _profession('farm'),
      _profession('season-1', parentId: 'farm'),
      _profession('season-2', parentId: 'farm'),
      _profession('nested-season', parentId: 'season-1'),
      _profession('other-farm'),
      _profession('other-season', parentId: 'other-farm'),
    ];

    expect(
      ProfessionService.professionTreeIds(professions, 'farm'),
      {'farm', 'season-1', 'season-2', 'nested-season'},
    );
  });

  test('activating a season deactivates every other active sibling only', () {
    final seasons = [
      _profession('active-1', parentId: 'farm'),
      _profession('active-2', parentId: 'farm'),
      _profession('inactive', parentId: 'farm', isActive: false),
      _profession('other-parent-active', parentId: 'other-farm'),
    ];
    final selected = _profession('new-season', parentId: 'farm');

    expect(
      ProfessionService.activeSeasonsToDeactivate(seasons, selected)
          .map((season) => season.id),
      containsAll(['active-1', 'active-2']),
    );
    expect(
      ProfessionService.activeSeasonsToDeactivate(seasons, selected)
          .map((season) => season.id),
      isNot(contains(anyOf('inactive', 'other-parent-active'))),
    );
  });

  test('removing a profession link preserves the account transaction', () {
    final date = DateTime(2026, 1, 1);
    final transaction = model.Transaction(
      id: 'transaction-1',
      accountId: 'account-1',
      amount: 1250,
      type: 'expense',
      category: 'EXP:Supplies',
      description: 'Seed purchase',
      date: date,
      createdAt: date,
      updatedAt: date,
      professionId: 'season-1',
      professionName: 'Farm',
    );

    final preserved = transaction.withoutProfession();

    expect(preserved.id, transaction.id);
    expect(preserved.accountId, transaction.accountId);
    expect(preserved.amount, transaction.amount);
    expect(preserved.accountBalanceAmount, transaction.accountBalanceAmount);
    expect(preserved.professionId, isNull);
    expect(preserved.professionName, transaction.professionName);
  });
}
