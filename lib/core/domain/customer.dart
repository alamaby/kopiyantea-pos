import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';

@freezed
class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String name,
    String? phone,
    String? email,
    required int loyaltyPoints,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Customer;
}
