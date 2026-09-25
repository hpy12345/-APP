import 'package:flutter/material.dart';

/// 分类模型 —— 19 个内置分类随数据库种子写入，支持后续自定义扩展（P2）。
///
/// 模拟版分类定义在 CATEGORIES 常量里，这里 schema 化进 `category` 表：
/// 换机恢复备份时连自定义分类一起回来，且统计聚合可直接 JOIN。
class LedgerCategory {
  final String id; // 'food' / 'salary' ...
  final String name;
  final String icon; // emoji
  final int bg; // 图标底色（ARGB int）
  final String type; // 'income' | 'expense'
  final int sort;
  final bool isCustom;

  const LedgerCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.bg,
    required this.type,
    this.sort = 0,
    this.isCustom = false,
  });

  Color get bgColor => Color(bg);

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'icon': icon,
        'bg': bg,
        'type': type,
        'sort': sort,
        'is_custom': isCustom ? 1 : 0,
      };

  static LedgerCategory fromRow(Map<String, Object?> r) => LedgerCategory(
        id: r['id'] as String,
        name: r['name'] as String,
        icon: r['icon'] as String,
        bg: (r['bg'] as int?) ?? 0xFFFDF9F4,
        type: r['type'] as String,
        sort: (r['sort'] as int?) ?? 0,
        isCustom: (r['is_custom'] as int? ?? 0) == 1,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'bg': bg,
        'type': type,
        'sort': sort,
        'isCustom': isCustom,
      };

  static LedgerCategory fromJson(Map b) => LedgerCategory(
        id: _str(b['id'], 'unknown'),
        name: _str(b['name'], '未命名'),
        icon: _str(b['icon'], '📦'),
        bg: _int(b['bg'], 0xFFFDF9F4),
        type: _str(b['type'], 'expense') == 'income' ? 'income' : 'expense',
        sort: _int(b['sort'], 0),
        isCustom: b['isCustom'] == true,
      );
}

// ── 备份 JSON 输入加固 ────────────────────────────────────
//
// 备份文件是用户可编辑、可跨版本携带的外部输入：字段类型不符时
// 直接 `as String` 会抛 TypeError，且发生在 Isolate 里，错误信息
// 对用户毫无意义。统一走「宽容转换 + 合理兜底」。

/// 任意值 → String。非字符串用 toString，null / 空用 [fallback]。
String _str(Object? v, String fallback) {
  if (v == null) return fallback;
  if (v is String) return v.isEmpty ? fallback : v;
  return v.toString();
}

/// 任意值 → int。数字取整；字符串尝试解析；其余用 [fallback]。
int _int(Object? v, int fallback) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// 资金账户（P1 账户体系扩展点；v1 只有「现金」一个默认账户）
class Account {
  final int id;
  final String name;
  final String icon;
  final int sort;

  const Account({required this.id, required this.name, this.icon = '💵', this.sort = 0});

  Map<String, Object?> toRow() => {'id': id, 'name': name, 'icon': icon, 'sort': sort};

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'icon': icon, 'sort': sort};
}
