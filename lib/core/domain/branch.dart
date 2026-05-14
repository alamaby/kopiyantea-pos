import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'branch.freezed.dart';

@freezed
class Branch with _$Branch {
  const factory Branch({
    required String id,
    required String name,
    String? address,
    String? phone,
    required String timezone,
    required bool isActive,
    required double taxPercentage,
    required String taxLabel,
    required bool taxInclusive,
    required int failedLoginLockoutThreshold,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Branch;
}

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String fullName,
    required GlobalRole globalRole,
    required bool isActive,
    required int failedLoginCount,
    DateTime? lockedUntil,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AppUser;
}

@freezed
class UserBranchAccess with _$UserBranchAccess {
  const factory UserBranchAccess({
    required String userId,
    required String branchId,
    BranchRole? roleAtBranch,
  }) = _UserBranchAccess;
}
