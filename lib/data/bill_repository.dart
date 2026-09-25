import 'package:sqflite/sqflite.dart';

import '../models/backup.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../utils/dates.dart';
import 'app_db.dart';
import 'seed.dart';

/// 账本数据仓库接口 —— 领域层只认它，不认 sqflite（依赖倒置，落地方案 3.2）。
/// 可被内存假实现替换做单元测试；未来云同步时新增实现类即可。
abstract class BillRepository {
  Future<void> ensureSeeded();
  Future<void> insertDemoData();

  Future<List<Bill>> loadBills(); // 未删除
  Future<void> insertBill(Bill bill);
  Future<void> softDelete(int id); // 删除可撤销 / 云同步预留
  Future<void> undelete(int id);

  Future<Map<String, int>> loadBudgets(); // monthKey → cents
  Future<void> upsertBudget(String month, int cents);
  Future<void> removeBudget(String month);

  Future<List<LedgerCategory>> loadCategories();

  // ── 聚合下推：SQL SUM + GROUP BY（万级数据 <10ms，落地方案 3.7 性能预算） ──
  Future<Wealth> wealth();
  Future<List<CategoryTotal>> expenseByCategory(int fromDate, int toDate);

  // ── 备份 ──
  Future<BackupDto> buildBackup(String appVersion);
  Future<ImportResult> importBackup(BackupDto dto, {required bool replaceAll});
}

/// 净资产聚合结果（SQL 计算字段）
class Wealth {
  final int cash; // Σ收入 − Σ支出（含借贷资金流动）
  final int receivable; // 别人欠我（借出 − 收回）
  final int payable; // 我欠别人（借入 − 还款）

  const Wealth({required this.cash, required this.receivable, required this.payable});

  /// 净债务 = 我欠别人 − 别人欠我（正 = 净欠钱）
  int get netDebt => payable - receivable;

  /// 净资产 = 现金 − 净债务
  int get netAsset => cash - netDebt;
}

class CategoryTotal {
  final String categoryId;
  final int cents;
  const CategoryTotal(this.categoryId, this.cents);
}

class ImportResult {
  final int bills;
  final int budgets;
  const ImportResult(this.bills, this.budgets);
}

/// sqflite 实现
class SqfliteBillRepository implements BillRepository {
  Future<Database> get _db => AppDb.instance();

  @override
  Future<void> ensureSeeded() async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      // INSERT OR IGNORE：幂等，重复启动 / 演示重置不报错不重复
      for (final c in Seed.categories) {
        batch.insert('category', c.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      batch.insert(
        'account',
        const Account(id: 1, name: '现金').toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> insertDemoData() async {
    final db = await _db;
    final batch = db.batch();
    for (final b in Seed.demoBills()) {
      batch.insert('bill', b.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Bill>> loadBills() async {
    final db = await _db;
    final rows = await db.query('bill',
        where: 'deleted = 0',
        orderBy: 'date DESC, created_at DESC, id DESC');
    return rows.map(Bill.fromRow).toList();
  }

  @override
  Future<void> insertBill(Bill bill) async {
    final db = await _db;
    await db.insert('bill', bill.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace); // uuid 幂等
  }

  @override
  Future<void> softDelete(int id) async {
    final db = await _db;
    await db.update('bill', {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> undelete(int id) async {
    final db = await _db;
    await db.update('bill', {'deleted': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, int>> loadBudgets() async {
    final db = await _db;
    final rows = await db.query('budget');
    return {for (final r in rows) r['month'] as String: r['cents'] as int};
  }

  @override
  Future<void> upsertBudget(String month, int cents) async {
    final db = await _db;
    await db.insert('budget', {'month': month, 'cents': cents},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> removeBudget(String month) async {
    final db = await _db;
    await db.delete('budget', where: 'month = ?', whereArgs: [month]);
  }

  @override
  Future<List<LedgerCategory>> loadCategories() async {
    final db = await _db;
    final rows = await db.query('category', orderBy: 'sort');
    return rows.map(LedgerCategory.fromRow).toList();
  }

  // ── SQL 聚合（直译落地方案 3.4 示例） ─────────────────────

  @override
  Future<Wealth> wealth() async {
    final db = await _db;
    // ① 现金 = Σ收入 − Σ支出
    final cashRows = await db.rawQuery(
        'SELECT COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE -amount END), 0) AS v '
        'FROM bill WHERE deleted = 0', ['income']);
    final cash = (cashRows.first['v'] as num?)?.toInt() ?? 0;

    // ② 债权债务（对齐模拟版 debtNet）
    final debtRows = await db.rawQuery(
        'SELECT category_id, SUM(amount) AS s FROM bill '
        "WHERE deleted = 0 AND category_id IN ('lend','collect','borrow','repay') "
        'GROUP BY category_id');
    int receivable = 0, payable = 0;
    for (final r in debtRows) {
      final s = (r['s'] as num?)?.toInt() ?? 0;
      final cat = r['category_id'] as String;
      if (cat == 'lend') receivable += s; // 借出 → 债权 +
      if (cat == 'collect') receivable -= s; // 收回 → 债权 −
      if (cat == 'borrow') payable += s; // 借入 → 债务 +
      if (cat == 'repay') payable -= s; // 还款 → 债务 −
    }
    return Wealth(cash: cash, receivable: receivable, payable: payable);
  }

  @override
  Future<List<CategoryTotal>> expenseByCategory(int fromDate, int toDate) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT category_id, SUM(amount) AS s FROM bill '
        'WHERE deleted = 0 AND type = ? AND date BETWEEN ? AND ? '
        'GROUP BY category_id ORDER BY s DESC',
        ['expense', fromDate, toDate]);
    return [
      for (final r in rows)
        CategoryTotal(r['category_id'] as String, (r['s'] as num?)?.toInt() ?? 0)
    ];
  }

  // ── 备份 ──────────────────────────────────────────────

  @override
  Future<BackupDto> buildBackup(String appVersion) async {
    final db = await _db;
    final billRows = await db.query('bill', where: 'deleted = 0');
    final budgetRows = await db.query('budget');
    final catRows = await db.query('category', orderBy: 'sort');
    final accRows = await db.query('account', orderBy: 'id');
    final now = DateTime.now();
    return BackupDto(
      meta: BackupMeta(
        schemaVersion: AppDb.version,
        appVersion: appVersion,
        exportedAt: now.toIso8601String(),
        billCount: billRows.length,
        budgetCount: budgetRows.length,
      ),
      categories: catRows.map(LedgerCategory.fromRow).toList(),
      accounts: [
        for (final r in accRows)
          Account(
            id: r['id'] as int,
            name: r['name'] as String,
            icon: (r['icon'] as String?) ?? '💵',
            sort: (r['sort'] as int?) ?? 0,
          ),
      ],
      bills: billRows.map(Bill.fromRow).toList(),
      budgets: [
        for (final r in budgetRows) Budget(month: r['month'] as String, cents: r['cents'] as int),
      ],
    );
  }

  @override
  Future<ImportResult> importBackup(BackupDto dto, {required bool replaceAll}) async {
    final db = await _db;
    // 全程事务：任何一步失败整体回滚，库保持导入前状态（失败不损坏数据）
    await db.transaction((txn) async {
      if (replaceAll) {
        await txn.delete('bill');
        await txn.delete('budget');
      }
      // 配置（分类 / 账户）随备份合并落地，同 id 覆盖 —— 换机自定义分类不丢
      final cfg = txn.batch();
      for (final c in dto.categories) {
        cfg.insert('category', c.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final a in dto.accounts) {
        cfg.insert('account', a.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await cfg.commit(noResult: true);

      // 账单 / 预算：按 uuid / month 幂等 upsert
      final batch = txn.batch();
      for (final b in dto.bills) {
        final row = b.toRow()..remove('id'); // 不带旧库自增 id
        batch.insert('bill', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final b in dto.budgets) {
        batch.insert('budget', b.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    return ImportResult(dto.bills.length, dto.budgets.length);
  }
}

/// 月度汇总（内存聚合辅助，供 ViewModel 使用）
class MonthSum {
  final int income;
  final int expense;
  const MonthSum(this.income, this.expense);
  int get balance => income - expense;
}

/// 账单列表聚合（首页当月结余等小聚合：数据已在内存，直译模拟版 sumUp）
MonthSum sumUp(List<Bill> list) {
  var income = 0, expense = 0;
  for (final b in list) {
    if (b.isIncome) {
      income += b.amount;
    } else {
      expense += b.amount;
    }
  }
  return MonthSum(income, expense);
}

/// 数据边界（流水翻页 / 步进器边界，直译模拟版 dataRange）
class DataRange {
  final int minDate; // 最早账单日
  final int maxDate; // 最晚账单日（不小于今天）
  final String minMonth;
  final String maxMonth;

  const DataRange(this.minDate, this.maxDate, this.minMonth, this.maxMonth);

  static DataRange of(List<Bill> bills) {
    final t = todayInt();
    if (bills.isEmpty) {
      final mk = monthKeyOf(t);
      return DataRange(t, t, mk, mk);
    }
    var mn = bills.first.date, mx = bills.first.date;
    for (final b in bills) {
      if (b.date < mn) mn = b.date;
      if (b.date > mx) mx = b.date;
    }
    if (mx < t) mx = t;
    if (mn > t) mn = t;
    return DataRange(mn, mx, monthKeyOf(mn), monthKeyOf(mx));
  }
}
