/// 日期工具 —— 全部「本地日历语义」。
///
/// 直译模拟版教训（方案 1.3 工程亮点 #1）：
/// 不使用 UTC 时间戳做天聚合，规避 `toISOString` 类偏移导致的跨日错位；
/// 落地方案决策 2：日期统一存 `yyyyMMdd` 整数（见 `models/bill.dart`）。
library;

String _p2(int n) => n.toString().padLeft(2, '0');

/// DateTime → yyyyMMdd 整数
int dateIntOf(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// yyyyMMdd → DateTime（当日 00:00，本地时区）
DateTime dtOf(int ymd) => DateTime(ymd ~/ 10000, (ymd % 10000) ~/ 100, ymd % 100);

int todayInt() => dateIntOf(DateTime.now());

/// yyyy-MM-dd（仅展示/交互层使用，不进数据库）
String todayDash() {
  final d = DateTime.now();
  return '${d.year}-${_p2(d.month)}-${_p2(d.day)}';
}

/// yyyyMMdd → 'yyyy-MM'（月键，预算与月聚合用）
String monthKeyOf(int ymd) => '${ymd ~/ 10000}-${_p2((ymd % 10000) ~/ 100)}';

String todayMonthKey() => monthKeyOf(todayInt());

/// 月键 → 当月某天 yyyyMMdd（day 自动 clamp 到该月天数）
int monthKeyDay(String mk, int day) {
  final y = int.parse(mk.substring(0, 4));
  final m = int.parse(mk.substring(5, 7));
  return y * 10000 + m * 100 + day.clamp(1, daysInMonth(y, m));
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// '2026-09' → '2026年9月'
String monthKeyCn(String mk) =>
    '${mk.substring(0, 4)}年${int.parse(mk.substring(5, 7))}月';

/// 20260925 → '9月25日'
String fmtDateCn(int ymd) => '${(ymd % 10000) ~/ 100}月${ymd % 100}日';

/// 20260925 → '2026-09-25'
String fmtDateDash(int ymd) =>
    '${ymd ~/ 10000}-${_p2((ymd % 10000) ~/ 100)}-${_p2(ymd % 100)}';

const List<String> _weeks = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/// 仅星期几（周标题不掺「今天/昨天」，与模拟版一致）
String weekLabel(int ymd) => _weeks[dtOf(ymd).weekday % 7];

/// 今天 / 昨天 / 周X
String dateLabel(int ymd) {
  final t = todayInt();
  if (ymd == t) return '今天';
  if (ymd == dateIntOf(DateTime.now().subtract(const Duration(days: 1)))) return '昨天';
  return weekLabel(ymd);
}

/// 相对今天偏移 n 天
int offsetTodayInt(int n) => dateIntOf(DateTime.now().add(Duration(days: n)));

/// 月份键步进：'2026-01' ± 1 → '2025-12' / '2026-02'
String monthKeyShift(String mk, int delta) {
  var y = int.parse(mk.substring(0, 4));
  var m = int.parse(mk.substring(5, 7)) + delta;
  while (m > 12) {
    m -= 12;
    y += 1;
  }
  while (m < 1) {
    m += 12;
    y -= 1;
  }
  return '$y-${_p2(m)}';
}

/// 日历浏览下限（与模拟版一致：2000 年）
const int calendarMinYear = 2000;
