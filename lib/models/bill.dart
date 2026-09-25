/// 账单模型。
///
/// 存储口径（落地方案 3.4 决策 1 / 2 / 3）：
/// - [amount] 单位为「分」（int），负数 = 冲销（如基金浮亏补仓 −240 元）
/// - [date] 为 `yyyyMMdd` 整数（本地日历语义，区间查询友好）
/// - [uuid] 幂等键（导入去重 / 未来云同步预留，v1 不启用同步但不留死角）
/// - [deleted] 软删除标记（删除可撤销；未来云同步 last-write-wins 预留）
class Bill {
  final int? id;
  final String uuid;
  final String type; // 'income' | 'expense'
  final int amount; // 分
  final String categoryId;
  final String note;
  final int date; // yyyyMMdd
  final int accountId; // 资金账户（v1 恒为 1=现金，P1 账户体系扩展点）
  final bool deleted;
  final int createdAt; // 毫秒时间戳，列表次序排序键
  final int updatedAt;

  const Bill({
    this.id,
    required this.uuid,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.date,
    this.accountId = 1,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == 'income';

  /// 该笔账对现金流的实际方向（直译模拟版符号语义）：
  /// 收入正数 → 流入；支出负数（冲销）→ 也算流入。
  bool get cashIn => isIncome ? amount >= 0 : amount < 0;

  Bill copyWith({
    int? id,
    String? uuid,
    String? type,
    int? amount,
    String? categoryId,
    String? note,
    int? date,
    int? accountId,
    bool? deleted,
    int? createdAt,
    int? updatedAt,
  }) =>
      Bill(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        note: note ?? this.note,
        date: date ?? this.date,
        accountId: accountId ?? this.accountId,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  // ── DB 行映射（snake_case 列名） ─────────────────────────
  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'note': note,
        'date': date,
        'account_id': accountId,
        'deleted': deleted ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  static Bill fromRow(Map<String, Object?> r) => Bill(
        id: r['id'] as int?,
        uuid: r['uuid'] as String? ?? '',
        type: r['type'] as String,
        amount: r['amount'] as int,
        categoryId: r['category_id'] as String,
        note: (r['note'] as String?) ?? '',
        date: r['date'] as int,
        accountId: (r['account_id'] as int?) ?? 1,
        deleted: (r['deleted'] as int? ?? 0) == 1,
        createdAt: r['created_at'] as int,
        updatedAt: (r['updated_at'] as int?) ?? 0,
      );

  // ── 备份 JSON（camelCase，对人类友好） ───────────────────
  Map<String, Object?> toJson() => {
        'uuid': uuid,
        'type': type,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'date': date,
        'accountId': accountId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

/// 结构校验（直译模拟版 validBill）：导入 / 读取时过滤脏数据。
bool isValidBillJson(Map b) {
  final t = b['type'];
  if (t is! String || (t != 'income' && t != 'expense')) return false;
  final a = b['amount'];
  if (a is! num || !a.isFinite) return false;
  if (b['categoryId'] is! String) return false;
  final d = b['date'];
  return d is int && d >= 20000101 && d <= 29991231;
}
