/// Entitlement snapshot — computed view of plan, subscription status,
/// usage counters, and feature flags for the current organization.
///
/// Immutable value object. Built from [OrganizationSubscriptionRow],
/// [SubscriptionPlanRow], [UsageCounterRow], and [OrganizationRow].
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.planCode,
    required this.subscriptionStatus,
    this.trialEndsAt,
    required this.maxProducts,
    required this.maxMonthlyTransactions,
    required this.maxBranches,
    required this.maxEmployees,
    required this.plusFeatures,
    required this.productsCount,
    required this.monthlyTransactionsCount,
    required this.branchesCount,
    required this.employeesCount,
    required this.isTrialExpired,
  });

  final String planCode; // 'free' | 'plus'
  final String subscriptionStatus; // 'trialing' | 'active' | 'past_due' | 'canceled' | 'expired'
  final DateTime? trialEndsAt;

  // Limits
  final int maxProducts;
  final int maxMonthlyTransactions;
  final int maxBranches;
  final int maxEmployees;

  // Feature flags
  final bool plusFeatures;

  // Current usage
  final int productsCount;
  final int monthlyTransactionsCount;
  final int branchesCount;
  final int employeesCount;

  // Derived
  final bool isTrialExpired;

  bool get isFree => planCode == 'free';
  bool get isPlus => planCode == 'plus';
  bool get canCreateProduct => productsCount < maxProducts;
  bool get canCreateTransaction => monthlyTransactionsCount < maxMonthlyTransactions;
  bool get canAddBranch => branchesCount < maxBranches;
  bool get canAddEmployee => employeesCount < maxEmployees;
  bool get canUsePlusFeatures => plusFeatures && !isTrialExpired;

  EntitlementSnapshot copyWith({
    String? planCode,
    String? subscriptionStatus,
    DateTime? trialEndsAt,
    int? maxProducts,
    int? maxMonthlyTransactions,
    int? maxBranches,
    int? maxEmployees,
    bool? plusFeatures,
    int? productsCount,
    int? monthlyTransactionsCount,
    int? branchesCount,
    int? employeesCount,
    bool? isTrialExpired,
  }) =>
      EntitlementSnapshot(
        planCode: planCode ?? this.planCode,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        trialEndsAt: trialEndsAt ?? this.trialEndsAt,
        maxProducts: maxProducts ?? this.maxProducts,
        maxMonthlyTransactions: maxMonthlyTransactions ?? this.maxMonthlyTransactions,
        maxBranches: maxBranches ?? this.maxBranches,
        maxEmployees: maxEmployees ?? this.maxEmployees,
        plusFeatures: plusFeatures ?? this.plusFeatures,
        productsCount: productsCount ?? this.productsCount,
        monthlyTransactionsCount: monthlyTransactionsCount ?? this.monthlyTransactionsCount,
        branchesCount: branchesCount ?? this.branchesCount,
        employeesCount: employeesCount ?? this.employeesCount,
        isTrialExpired: isTrialExpired ?? this.isTrialExpired,
      );

  /// Default fallback for unauthenticated / no-org state.
  static const EntitlementSnapshot free = EntitlementSnapshot(
    planCode: 'free',
    subscriptionStatus: 'active',
    maxProducts: 50,
    maxMonthlyTransactions: 100,
    maxBranches: 1,
    maxEmployees: 0,
    plusFeatures: false,
    productsCount: 0,
    monthlyTransactionsCount: 0,
    branchesCount: 0,
    employeesCount: 0,
    isTrialExpired: false,
  );
}
