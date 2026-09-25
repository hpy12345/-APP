import '../models/bill.dart';
import '../models/category.dart';
import '../utils/dates.dart';

/// 内置分类种子（直译模拟版 CATEGORIES，19 个）与首启演示数据。
///
/// 与模拟版的差异（落地方案 P0 #4）：
/// 首启**不再默认注入**示例账单，改为空账本 + 引导对话框「体验演示数据」，
/// 避免污染用户真实账本。
class Seed {
  Seed._();

  static const _c = 0xFF; // ARGB 前缀简写

  // 注意：非 const（含方法调用），LedgerCategory 构造本身为 const 不影响
  static final List<LedgerCategory> categories = [
    // ── 支出 11 ──
    LedgerCategory(id: 'food', name: '餐饮', icon: '🍜', bg: _cf(0xF7E6D6), type: 'expense', sort: 0),
    LedgerCategory(id: 'traffic', name: '交通', icon: '🚇', bg: _cf(0xDFE6EA), type: 'expense', sort: 1),
    LedgerCategory(id: 'shopping', name: '购物', icon: '🛍️', bg: _cf(0xF4DDE2), type: 'expense', sort: 2),
    LedgerCategory(id: 'fun', name: '娱乐', icon: '🎮', bg: _cf(0xE6DFEE), type: 'expense', sort: 3),
    LedgerCategory(id: 'medical', name: '医疗', icon: '💊', bg: _cf(0xDCEBE0), type: 'expense', sort: 4),
    LedgerCategory(id: 'housing', name: '居住', icon: '🏠', bg: _cf(0xF5E7CB), type: 'expense', sort: 5),
    LedgerCategory(id: 'study', name: '学习', icon: '📚', bg: _cf(0xDDE4EC), type: 'expense', sort: 6),
    LedgerCategory(id: 'invest_out', name: '理财', icon: '📉', bg: _cf(0xDBE5E3), type: 'expense', sort: 7),
    LedgerCategory(id: 'lend', name: '借出', icon: '🤝', bg: _cf(0xE8E2F0), type: 'expense', sort: 8),
    LedgerCategory(id: 'repay', name: '还款', icon: '📤', bg: _cf(0xF6DEE0), type: 'expense', sort: 9),
    LedgerCategory(id: 'other', name: '其他', icon: '📦', bg: _cf(0xEAE5DC), type: 'expense', sort: 10),
    // ── 收入 8 ──
    LedgerCategory(id: 'salary', name: '工资', icon: '💰', bg: _cf(0xDCEBE0), type: 'income', sort: 11),
    LedgerCategory(id: 'bonus', name: '奖金', icon: '🧧', bg: _cf(0xF6DEDB), type: 'income', sort: 12),
    LedgerCategory(id: 'invest', name: '理财', icon: '📈', bg: _cf(0xDDE8E0), type: 'income', sort: 13),
    LedgerCategory(id: 'parttime', name: '兼职', icon: '💼', bg: _cf(0xE6E1EF), type: 'income', sort: 14),
    LedgerCategory(id: 'gift', name: '他人赠予', icon: '🎁', bg: _cf(0xF7E3D8), type: 'income', sort: 15),
    LedgerCategory(id: 'borrow', name: '借入', icon: '📥', bg: _cf(0xDCEBE6), type: 'income', sort: 16),
    LedgerCategory(id: 'collect', name: '收回欠款', icon: '💵', bg: _cf(0xDCEAE0), type: 'income', sort: 17),
    LedgerCategory(id: 'refund', name: '退款', icon: '↩️', bg: _cf(0xE2EAE4), type: 'income', sort: 18),
  ];

  static int _cf(int rgb) => _c << 24 | rgb;

  /// 演示账单（直译模拟版 sampleBills，金额换算为分）。
  /// 覆盖上上月至本月，含负金额冲销与借贷四分类，用于演示净资产拆解模型。
  static List<Bill> demoBills() {
    final now = DateTime.now();
    final y = now.year, m = now.month;
    final today = now.day;
    final near = today; // 示例日期不落在未来（允许落在今天）
    int clamp(int n) => n < 1 ? 1 : (n > near ? near : n);

    int d(int day) => dateIntOf(DateTime(y, m, clamp(day)));
    // 上月 / 上上月的同结构日期
    int dm(int monthsAgo, int day) {
      final dt = DateTime(y, m - monthsAgo, 1);
      final last = daysInMonth(dt.year, dt.month);
      return dt.year * 10000 + dt.month * 100 + day.clamp(1, last);
    }

    final t = DateTime.now().millisecondsSinceEpoch;
    int seq = 0;
    Bill bill(String type, int yuanCents, String cat, String note, int date) => Bill(
          uuid: 'demo-${(seq++).toString().padLeft(4, '0')}',
          type: type,
          amount: yuanCents,
          categoryId: cat,
          note: note,
          date: date,
          createdAt: t + seq * 1000,
          updatedAt: t + seq * 1000,
        );

    final yesterday = today - 1 < 1 ? 1 : today - 1;
    return [
      // ── 上上月 ──
      bill('income', 1230000, 'salary', '工资', dm(2, 10)),
      bill('expense', 310000, 'housing', '房租', dm(2, 5)),
      bill('expense', 142000, 'food', '日常三餐', dm(2, 18)),
      bill('income', 210000, 'bonus', '季度奖金', dm(2, 20)),
      // ── 上月 ──
      bill('income', 1280000, 'salary', '工资', dm(1, 10)),
      bill('expense', 320000, 'housing', '房租', dm(1, 5)),
      bill('expense', 168000, 'food', '餐饮合计', dm(1, 16)),
      bill('expense', 88000, 'shopping', '换季衣物', dm(1, 22)),
      bill('income', 42000, 'invest', '理财收益', dm(1, 25)),
      // ── 本月 ──
      bill('income', 1280000, 'salary', '工资', d(10)),
      bill('income', 86000, 'invest', '基金分红', d(15)),
      bill('income', 50000, 'gift', '爸妈给的零花', d(8)),
      bill('income', 30000, 'borrow', '向室友借的钱', d(12)),
      bill('expense', 3850, 'food', '楼下面馆', d(today)),
      bill('expense', 1200, 'traffic', '地铁通勤', d(today)),
      bill('expense', 26800, 'shopping', '秋装一件', d(yesterday)),
      bill('expense', 4500, 'fun', '电影票', d(yesterday)),
      bill('expense', 15600, 'food', '同事聚餐 AA', d(yesterday)),
      bill('expense', 8990, 'medical', '感冒药+口罩', d(clamp(today - 2))),
      bill('expense', 320000, 'housing', '房租', d(5)),
      bill('expense', 6280, 'shopping', '洗发水卫生纸', d(4)),
      bill('expense', 12900, 'study', '技术书两本', d(3)),
      bill('expense', -24000, 'invest_out', '基金浮亏补仓', d(6)), // 负金额冲销
      bill('expense', 80000, 'lend', '借给同学周转', d(2)),
      bill('expense', 30000, 'repay', '还室友的钱', d(yesterday)),
    ];
  }
}
