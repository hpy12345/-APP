import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bill.dart';
import 'budget.dart';
import 'category.dart';

/// 当前数据库 schema 版本（单一出处：`AppDb.version` 与此保持一致）
const int kCurrentSchemaVersion = 4;

/// 全量备份 DTO（JSON 格式）。
///
/// 设计要点（落地方案 3.4 / 3.5）：
/// - 含 `meta.schemaVersion`：导入时校验「备份不来自更高版本」，保证向下兼容
/// - 含分类 / 账户配置：换机恢复时自定义分类不丢
/// - 账单带 uuid：导入按 uuid 幂等去重（合并模式）
class BackupDto {
  final BackupMeta meta;
  final List<LedgerCategory> categories;
  final List<Account> accounts;
  final List<Bill> bills;
  final List<Budget> budgets;

  const BackupDto({
    required this.meta,
    required this.categories,
    required this.accounts,
    required this.bills,
    required this.budgets,
  });

  Map<String, Object?> toJson() => {
        'meta': meta.toJson(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'bills': bills.map((b) => b.toJson()).toList(),
        'budgets': budgets.map((b) => b.toJson()).toList(),
      };
}

class BackupMeta {
  /// 备份导出时的数据库 schema 版本
  final int schemaVersion;
  final String appVersion;
  final String exportedAt; // ISO 8601
  final int billCount;
  final int budgetCount;

  const BackupMeta({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.billCount,
    required this.budgetCount,
  });

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'exportedAt': exportedAt,
        'billCount': billCount,
        'budgetCount': budgetCount,
        'note': '记账本全量备份',
      };
}

/// 同步解析（小文件）
BackupDto parseBackup(String raw) => _parseRaw(raw);

/// Isolate 内解析（落地方案性能预算：5 万条账单导入不卡 UI）
Future<BackupDto> parseBackupAsync(String raw) => compute(_parseRaw, raw);

BackupDto _parseRaw(String raw) {
  final dynamic root;
  try {
    root = jsonDecode(raw);
  } catch (_) {
    throw const FormatException('不是有效的 JSON 文件');
  }
  if (root is! Map) throw const FormatException('备份结构不正确');

  // ── meta ──────────────────────────────────────────────
  final meta = root['meta'];
  if (meta is! Map) throw const FormatException('备份缺少 meta 信息');
  final schemaVersion = _toInt(meta['schemaVersion'], 0);
  if (schemaVersion > kCurrentSchemaVersion) {
    throw FormatException('该备份来自更新版本的应用（数据库 v$schemaVersion），'
        '请先升级 App 再导入');
  }

  // ── bills：逐条结构校验（直译模拟版 validBill） ──────────
  final rawBills = root['bills'];
  if (rawBills is! List) throw const FormatException('备份缺少账单数据');
  final bills = <Bill>[];
  for (var i = 0; i < rawBills.length; i++) {
    final b = rawBills[i];
    if (b is! Map) continue; // 容错跳过脏行
    final map = Map<String, dynamic>.from(b);
    if (!isValidBillJson(map)) continue;
    // type / amount / categoryId / date 已由 isValidBillJson 保证类型，
    // 其余字段走宽容转换 —— 备份是用户可手改的文件，类型不符不该崩。
    final uuid =
        map['uuid']?.toString() ?? 'imported-$i-${map['date']}';
    bills.add(Bill(
      uuid: uuid,
      type: map['type'] as String,
      amount: (map['amount'] as num).round(),
      categoryId: map['categoryId'] as String,
      note: map['note']?.toString() ?? '',
      date: map['date'] as int,
      accountId: _toInt(map['accountId'], 1),
      deleted: false,
      createdAt: _toInt(map['createdAt'], 0),
      updatedAt: _toInt(map['updatedAt'], 0),
    ));
  }
  if (bills.isEmpty && rawBills.isNotEmpty) {
    throw const FormatException('备份中没有一条有效账单');
  }

  // ── budgets ───────────────────────────────────────────
  final budgets = <Budget>[];
  final rawBudgets = root['budgets'];
  if (rawBudgets is List) {
    for (final b in rawBudgets) {
      if (b is! Map) continue;
      final m = b['month'];
      final c = b['cents'];
      if (m is String && RegExp(r'^\d{4}-\d{2}$').hasMatch(m) && c is num) {
        budgets.add(Budget(month: m, cents: c.round()));
      }
    }
  }

  // ── categories / accounts（配置随备份走） ───────────────
  final categories = <LedgerCategory>[];
  final rawCats = root['categories'];
  if (rawCats is List) {
    for (final c in rawCats) {
      if (c is Map && c['id'] is String && c['name'] is String) {
        categories.add(LedgerCategory.fromJson(Map<String, dynamic>.from(c)));
      }
    }
  }
  final accounts = <Account>[];
  final rawAccs = root['accounts'];
  if (rawAccs is List) {
    for (final a in rawAccs) {
      if (a is Map && a['id'] is num && a['name'] is String) {
        accounts.add(Account(
          id: (a['id'] as num).toInt(),
          name: a['name'] as String,
          icon: a['icon']?.toString() ?? '💵',
          sort: _toInt(a['sort'], 0),
        ));
      }
    }
  }

  return BackupDto(
    meta: BackupMeta(
      schemaVersion: schemaVersion,
      appVersion: meta['appVersion']?.toString() ?? '',
      exportedAt: meta['exportedAt']?.toString() ?? '',
      billCount: bills.length,
      budgetCount: budgets.length,
    ),
    categories: categories,
    accounts: accounts,
    bills: bills,
    budgets: budgets,
  );
}

/// 宽容取整：数字取整、字符串尝试解析、其余兜底 [fallback]。
/// 用于备份这种「用户可手改的外部输入」，避免 `as int` 直接抛 TypeError。
int _toInt(Object? v, int fallback) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}
