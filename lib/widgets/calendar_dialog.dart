import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../theme/palette.dart';
import '../utils/dates.dart';

/// 自定义日历弹层（复刻模拟版 .cal）：
/// - 日粒度 → 月历：三色记账圆点 / 今天描边 / 选中印章 / 未来禁用
/// - 月粒度 → 年历：12 宫格 + 记账金点
/// - 游标可自由前后翻（下限 2000 年，上限今天）
///
/// 「本月 / 今天」语义按落地方案 P0 修正：日粒度下「本月」= 跳当月 1 号，
/// 与「今天」区分开（模拟版两按钮行为重复，属已知局限 #11）。
Future<void> showLedgerCalendar(
  BuildContext context, {
  required bool monthGrain,
  required int initYear,
  required int initMonth,
  required int selectedDate,
  required String selectedMonth,
  required List<Bill> bills,
  required ValueChanged<int> onPickDate,
  required ValueChanged<String> onPickMonth,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: const Color(0x75231C14), // rgba(35,28,20,.46)
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondary) => _CalendarDialog(
      monthGrain: monthGrain,
      initYear: initYear,
      initMonth: initMonth,
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
      bills: bills,
      onPickDate: onPickDate,
      onPickMonth: onPickMonth,
    ),
  );
}

class _CalendarDialog extends StatefulWidget {
  final bool monthGrain;
  final int initYear;
  final int initMonth;
  final int selectedDate;
  final String selectedMonth;
  final List<Bill> bills;
  final ValueChanged<int> onPickDate;
  final ValueChanged<String> onPickMonth;

  const _CalendarDialog({
    required this.monthGrain,
    required this.initYear,
    required this.initMonth,
    required this.selectedDate,
    required this.selectedMonth,
    required this.bills,
    required this.onPickDate,
    required this.onPickMonth,
  });

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initYear;
    _month = widget.initMonth;
  }

  int get _todayInt => todayInt();
  String get _todayMonth => todayMonthKey();

  void _shift(int delta) {
    setState(() {
      if (widget.monthGrain) {
        _year += delta;
      } else {
        var m = _month + delta;
        if (m > 12) {
          m = 1;
          _year += 1;
        } else if (m < 1) {
          m = 12;
          _year -= 1;
        }
        _month = m;
      }
    });
  }

  bool get _canPrev {
    if (widget.monthGrain) return _year > calendarMinYear;
    return _year > calendarMinYear || _month > 1;
  }

  bool get _canNext {
    final now = DateTime.now();
    if (widget.monthGrain) return _year < now.year;
    if (_year < now.year) return true;
    return _month < now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 356,
        padding: const EdgeInsets.all(1), // 描金外框
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.paper, Palette.card]),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Palette.gold),
          boxShadow: const [
            BoxShadow(
                color: Color(0x3D231C14),
                offset: Offset(0, 22),
                blurRadius: 54),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.paper, Palette.card]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0x47B08D4F)), // 描金内框
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHead(),
              if (!widget.monthGrain) ...[
                const SizedBox(height: 8),
                _buildWeekHeader(),
              ],
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: widget.monthGrain ? _buildYearGrid() : _buildMonthGrid(),
                ),
              ),
              const SizedBox(height: 10),
              _buildFoot(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 头部：标题 + 翻页 ───────────────────────────────────
  Widget _buildHead() {
    final title = widget.monthGrain
        ? '$_year年'
        : '$_year年$_month月';
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: serifStyle.copyWith(
                  fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
        ),
        _navBtn(Icons.chevron_left, _canPrev, () => _shift(-1)),
        const SizedBox(width: 4),
        _navBtn(Icons.chevron_right, _canNext, () => _shift(1)),
      ],
    );
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Material(
        color: const Color(0xFFFAF5EA),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Palette.line),
            ),
            child: Icon(icon, size: 18, color: Palette.textSub),
          ),
        ),
      ),
    );
  }

  // ── 星期表头 ────────────────────────────────────────────
  Widget _buildWeekHeader() {
    const weeks = ['日', '一', '二', '三', '四', '五', '六'];
    return Row(
      children: [
        for (final w in weeks)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(w,
                  textAlign: TextAlign.center,
                  style: serifStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Palette.textSub,
                      letterSpacing: 1)),
            ),
          ),
      ],
    );
  }

  // ── 月历（选日期） ─────────────────────────────────────
  Widget _buildMonthGrid() {
    final curKey = '$_year-${_month.toString().padLeft(2, '0')}';

    // 当月聚合：date → {exp, inc}
    final agg = <int, Map<String, int>>{};
    for (final b in widget.bills) {
      if (monthKeyOf(b.date) != curKey) continue;
      final o = agg.putIfAbsent(b.date, () => {'exp': 0, 'inc': 0});
      if (b.isIncome) {
        o['inc'] = o['inc']! + b.amount;
      } else {
        o['exp'] = o['exp']! + b.amount;
      }
    }

    final lead = DateTime(_year, _month, 1).weekday % 7; // 1 号是周几（0=周日）
    final days = daysInMonth(_year, _month);

    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= days; day++) {
      final ds = _year * 10000 + _month * 100 + day;
      cells.add(_dayCell(ds, agg[ds]));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 0.92,
      children: cells,
    );
  }

  Widget _dayCell(int ds, Map<String, int>? agg) {
    final isFuture = ds > _todayInt;
    final isSel = ds == widget.selectedDate;
    final isToday = ds == _todayInt;
    final day = ds % 100;

    // 圆点：both（红绿各半）/ inc（绿）/ 默认红（有支出）
    Widget? dot;
    if (agg != null) {
      final hasExp = (agg['exp'] ?? 0) > 0;
      final hasInc = (agg['inc'] ?? 0) > 0;
      if (hasExp && hasInc) {
        dot = _dot(const LinearGradient(
            colors: [Palette.expense, Palette.income],
            stops: [0.5, 0.5]));
      } else if (hasInc) {
        dot = _dot(const LinearGradient(colors: [Palette.income, Palette.income]));
      } else {
        dot = _dot(const LinearGradient(colors: [Palette.expense, Palette.expense]));
      }
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: isFuture
            ? null
            : () {
                widget.onPickDate(ds);
                Navigator.of(context).pop();
              },
        child: Container(
          decoration: isSel
              ? BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment(-0.5, -0.6),
                      end: Alignment(0.5, 0.8),
                      colors: [Color(0xFFA84A3C), Color(0xFF8A3229)]),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x577E2E26),
                        offset: Offset(0, 3),
                        blurRadius: 10),
                  ],
                )
              : isToday
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Palette.brand, width: 1.4),
                    )
                  : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: serifStyle.copyWith(
                    fontSize: 13.5,
                    fontWeight: (isSel || isToday) ? FontWeight.w700 : FontWeight.w400,
                    color: isSel
                        ? const Color(0xFFFDF6EC)
                        : isFuture
                            ? const Color(0xFFCEC4B2)
                            : isToday
                                ? Palette.brand
                                : Palette.text,
                  )),
              const SizedBox(height: 2),
              SizedBox(
                height: 4.5,
                width: 4.5,
                child: isSel && dot != null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFDF6EC)))
                    : (agg != null ? dot : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Gradient gradient) =>
      Container(width: 4.5, height: 4.5, decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient));

  // ── 年历（选月份） ─────────────────────────────────────
  Widget _buildYearGrid() {
    final monthsWithRecords = widget.bills.map((b) => monthKeyOf(b.date)).toSet();
    final cells = <Widget>[];
    for (var m = 1; m <= 12; m++) {
      final mk = '$_year-${m.toString().padLeft(2, '0')}';
      cells.add(_monthCell(mk, m, monthsWithRecords.contains(mk)));
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: cells,
    );
  }

  Widget _monthCell(String mk, int m, bool hasRecords) {
    final isFuture = mk.compareTo(_todayMonth) > 0;
    final isSel = mk == widget.selectedMonth;
    final isNow = mk == _todayMonth;

    return Material(
      color: isSel
          ? Palette.brandSoft
          : isNow
              ? const Color(0xFFFDF6F2)
              : Palette.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isFuture
            ? null
            : () {
                widget.onPickMonth(mk);
                Navigator.of(context).pop();
              },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel
                  ? const Color(0x4D9E4034)
                  : isNow
                      ? const Color(0x619E4034)
                      : Palette.line,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('$m月',
                  style: serifStyle.copyWith(
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                      color: isSel
                          ? Palette.brand
                          : isFuture
                              ? const Color(0xFFC9C0B0)
                              : isNow
                                  ? Palette.brand
                                  : Palette.text)),
              if (hasRecords && !isFuture)
                Positioned(
                  bottom: 5,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Palette.gold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 底部：图例 + 本月 / 今天 ─────────────────────────────
  Widget _buildFoot() {
    return Column(
      children: [
        const Divider(height: 1, color: Palette.line),
        const SizedBox(height: 10),
        Row(
          children: [
            _legendDot(const LinearGradient(colors: [Palette.expense, Palette.expense])),
            const SizedBox(width: 3),
            Text('支出', style: _legendStyle),
            const SizedBox(width: 10),
            _legendDot(const LinearGradient(colors: [Palette.income, Palette.income])),
            const SizedBox(width: 3),
            Text('收入', style: _legendStyle),
            const SizedBox(width: 10),
            _legendDot(const LinearGradient(
                colors: [Palette.expense, Palette.income], stops: [0.5, 0.5])),
            const SizedBox(width: 3),
            Text('都有', style: _legendStyle),
            const Spacer(),
            _footBtn('本月', Colors.transparent, () {
              final now = DateTime.now();
              if (widget.monthGrain) {
                widget.onPickMonth(todayMonthKey());
              } else {
                // 语义修正（方案 P0）：日粒度「本月」= 当月 1 号
                widget.onPickDate(now.year * 10000 + now.month * 100 + 1);
              }
              Navigator.of(context).pop();
            }),
            const SizedBox(width: 6),
            _footBtn('今天', Palette.brandSoft, () {
              if (widget.monthGrain) {
                widget.onPickMonth(todayMonthKey());
              } else {
                widget.onPickDate(todayInt());
              }
              Navigator.of(context).pop();
            }),
          ],
        ),
      ],
    );
  }

  static const _legendStyle = TextStyle(
      fontSize: 11, color: Palette.textSub, letterSpacing: 1);

  Widget _legendDot(Gradient g) => Container(
      width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, gradient: g));

  Widget _footBtn(String label, Color bg, VoidCallback onTap) {
    return Material(
      color: bg == Colors.transparent ? const Color(0xFFFAF5EA) : bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.line),
          ),
          child: Text(label,
              style: serifStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: label == '今天' ? Palette.brand : Palette.textSub,
                  letterSpacing: 1.2)),
        ),
      ),
    );
  }
}
