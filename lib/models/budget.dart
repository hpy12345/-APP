/// 月度预算：month 为 'yyyy-MM' 键（与模拟版 `ledger.budgets.v1` 语义一致），
/// cents 为分。
class Budget {
  final String month;
  final int cents;

  const Budget({required this.month, required this.cents});

  Map<String, Object?> toRow() => {'month': month, 'cents': cents};

  Map<String, Object?> toJson() => {'month': month, 'cents': cents};
}
