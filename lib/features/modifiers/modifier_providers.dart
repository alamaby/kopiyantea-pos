import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/option_dao.dart';

part 'modifier_providers.g.dart';

/// FEAT-001 — reactive list of all modifier groups (chain-wide).
@riverpod
Stream<List<OptionGroupRow>> allOptionGroups(AllOptionGroupsRef ref) {
  return ref.watch(optionDaoProvider).watchAllGroups();
}

/// Reactive list of options inside a single group.
@riverpod
Stream<List<OptionRow>> optionsForGroup(
  OptionsForGroupRef ref,
  String groupId,
) {
  return ref.watch(optionDaoProvider).watchOptionsForGroup(groupId);
}

/// Reactive list of groups bound to a given product (with options eager-loaded).
@riverpod
Stream<List<OptionGroupWithOptions>> productOptionGroups(
  ProductOptionGroupsRef ref,
  String productId,
) {
  return ref.watch(optionDaoProvider).watchGroupsForProduct(productId);
}
