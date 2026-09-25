/// 金额工具 —— 存储单位一律为「分」（int），展示层再除 100。
///
/// 落地方案决策 1：`0.1 + 0.2 != 0.3` 的浮点误差在账本不可接受，
/// 模拟版 `Math.round(x*100)/100` 只修显示层，存储层在此根治。
library;

import 'package:intl/intl.dart';

final NumberFormat _fmt2 = NumberFormat('#,##0.00', 'zh_CN');
final NumberFormat _fmt0 = NumberFormat('#,##0', 'zh_CN');

/// 分 → 千分位两位小数字符串（取绝对值，符号由调用方拼）。
/// 3850 → '38.50'；-24000 → '240.00'
String fmtCents(int cents) => _fmt2.format(cents.abs() / 100);

/// 分 → 紧凑格式（图表中心 / 净资产右栏用）。
/// ≥1万 → 'x.x万'；≥1000 → 千分位整数；否则整数或两位小数（与模拟版 fmtShort 一致）
String fmtCentsShort(int cents) {
  final v = cents.abs() / 100;
  if (v >= 10000) {
    final w = (v / 10000).toStringAsFixed(1);
    return '${w.replaceAll(RegExp(r'\.0$'), '')}万';
  }
  if (v >= 1000) return _fmt0.format(v);
  return v % 1 == 0 ? _fmt0.format(v) : _fmt2.format(v);
}

/// 键盘输入缓冲（元）→ 分。'38.5' → 3850
int bufferToCents(String buffer) => ((double.tryParse(buffer) ?? 0) * 100).round();

/// 分 → 元的展示字符串（输入回填等）：3850 → '38.5'（去尾零）
String centsToBuffer(int cents) {
  final v = cents.abs() / 100;
  final s = v.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'\.?0+$'), '');
}
