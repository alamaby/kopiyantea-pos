import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    String? category,
    required double basePrice,
    String? sku,
    String? imageUrl,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Product;
}

@freezed
class BranchProduct with _$BranchProduct {
  const factory BranchProduct({
    required String productId,
    required String branchId,
    double? priceOverride,
    required bool isAvailable,
    String? customName,
    required double discountPercentage,
    DateTime? discountValidUntil,
  }) = _BranchProduct;
}
