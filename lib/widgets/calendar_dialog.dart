import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../theme/palette.dart';
import '../utils/dates.dart';

/// 日历粒度
/// - [day]   → 月历（选日期）
/// - [month] → 年历 12 宫格（选月份）
/// - [year]  → 12 年宫格（选年份，统计页年粒度用）
enum CalendarGrain { day, month, year }

/// 自定义日历弹层（复刻模拟版 .cal）：
/// - 日粒度 → 月历：三色记账圆点 / 今天描边 / 选中印章 / 未来禁用
/// - 月粒度 → 年历：12 宫格 + 记账金点
/// - 年粒度 → 年份宫格：12 年一格
/// - 游标可自由前后翻（下限 2000 年，上限今天）
///
/// 「本月 / 今天」语义按落地方案 P0 修正：日粒度下「本月」= 跳当月 1 号，
/// 与「今天」区分开（模拟版两按钮行为重复，属已知局限 #11）。
Future<void> showLedgerCalendar(
  BuildContext context, {
  required CalendarGrain grain,
  required int initYear,
  required int initMonth,
  required int selectedDate,
  required String selectedMonth,
  required List<Bill> bills,
  ValueChanged<int>? onPickDate,
  ValueChanged<String>? onPickMonth,
  ValueChanged<int>? onPickYear,
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
      grain: grain,
      initYear: initYear,
      initMonth: initMonth,
      selectedDate: selectedDate,
      selectedMonth: selectedMonth,
      bills: bills,
      onPickDate: onPickDate,
      onPickMonth: onPickMonth,
      onPickYear: onPickYear,
    ),
  );
}

class _CalendarDialog extends StatefulWidget {
  final CalendarGrain grain;
  final int initYear;
  final int initMonth;
  final int selectedDate;
  final String selectedMonth;
  final List<Bill> bills;
  final ValueChanged<int>? onPickDate;
  final ValueChanged<String>? onPickMonth;
  final ValueChanged<int>? onPickYear;

  const _CalendarDialog({
    required this.grain,
    required this.initYear,
    required this.initMonth,
    required this.selectedDate,
    required this.selectedMonth,
    required this.bills,
    this.onPickDate,
    this.onPickMonth,
    this.onPickYear,
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

  /// 年粒度下 12 年一屏的起始年
  int get _blockStart => (_year ~/ 12) * 12;

  void _shift(int delta) {
    setState(() {
      if (widget.grain == CalendarGrain.year) {
        _year = _blockStart + delta * 12;
      } else if (widget.grain == CalendarGrain.month) {
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
    if (widget.grain == CalendarGrain.year) return _blockStart > calendarMinYear;
    if (widget.grain == CalendarGrain.month) return _year > calendarMinYear;
    return _year > calendarMinYear || _month > 1;
  }

  bool get _canNext {
    final now = DateTime.now();
    if (widget.grain == CalendarGrain.year) {
      // 当前年所在的这一屏之后还有可见年份时才允许前进
      return _blockStart + 12 <= now.year;
    }
    if (widget.grain == CalendarGrain.month) return _year < now.year;
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
            border: Border.all(color: const Color(0x47B08D4F)), // 描金内框
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHead(),
              if (widget.grain == CalendarGrain.day) ...[
                const SizedBox(height: 8),
                _buildWeekHeader(),
              ],
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: switch (widget.grain) {
                    CalendarGrain.day => _buildDayGrid(),
                    CalendarGrain.month => _buildMonthCells(),
                    CalendarGrain.year => _buildYearCells(),
                  },
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
    final title = switch (widget.grain) {
      CalendarGrain.day => '$_year年$_month月',
      CalendarGrain.month => '$_year年',
      CalendarGrain.year => '$_blockStart - ${_blockStart + 11} 年',
    };
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
  Widget _buildDayGrid() {
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
                widget.onPickDate?.call(ds);
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
  Widget _buildMonthCells() {
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
                widget.onPickMonth?.call(mk);
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

  // ── 年份宫格（选年份） ─────────────────────────────────
  Widget _buildYearCells() {
    final now = DateTime.now();
    final yearsWithRecords =
        widget.bills.map((b) => b.date ~/ 10000).toSet();
    final cells = <Widget>[];
    for (var y = _blockStart; y < _blockStart + 12; y++) {
      cells.add(_yearCell(y, now.year, yearsWithRecords.contains(y)));
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

  Widget _yearCell(int y, int nowYear, bool hasRecords) {
    final isFuture = y > nowYear;
    final isSel = y == _year;
    final isNow = y == nowYear;

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
                widget.onPickYear?.call(y);
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
              Text('$y',
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

  // ── 底部：图例 + 快捷按钮 ───────────────────────────────
  //
  // 图例（日粒度：支出 / 收入 / 都有）**必须单行**：折行会把日历底部顶高、
  // 挤压日期网格。这里用 FittedBox(scaleDown) 兜底 —— 系统字号放大时宁可整体
  // 缩一点也不换行；右侧按钮同时收窄（见 _footBtn），把宽度让给图例。
  Widget _buildFoot() {
    final now = DateTime.now();
    return Column(
      children: [
        const Divider(height: 1, color: Palette.line),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _legend(),
              ),
            ),
            const SizedBox(width: 10),
            ..._footButtons(now),
          ],
        ),
      ],
    );
  }

  Widget _legend() {
    if (widget.grain != CalendarGrain.day) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Palette.gold),
          ),
          const SizedBox(width: 5),
          const Text('有记账', style: _legendStyle),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendItem(const LinearGradient(
            colors: [Palette.expense, Palette.expense]), '支出'),
        const SizedBox(width: 9),
        _legendItem(const LinearGradient(
            colors: [Palette.income, Palette.income]), '收入'),
        const SizedBox(width: 9),
        _legendItem(const LinearGradient(
            colors: [Palette.expense, Palette.income],
            stops: [0.5, 0.5]), '都有'),
      ],
    );
  }

  static const _legendStyle = TextStyle(
      fontSize: 11, color: Palette.textSub, letterSpacing: 1);

  Widget _legendItem(Gradient g, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: g)),
        const SizedBox(width: 4),
        Text(label, style: _legendStyle),
      ],
    );
  }

  List<Widget> _footButtons(DateTime now) {
    // 日粒度只留「今天」：原来的「本月」＝跳当月 1 号，与「今天」几乎重复，
    // 还占着宽度把图例挤到折行（用户反馈：日粒度下这个按钮没用）。
    if (widget.grain == CalendarGrain.day) {
      return [
        _footBtn('今天', Palette.brandSoft, () {
          widget.onPickDate?.call(_todayInt);
          Navigator.of(context).pop();
        }),
      ];
    }
    if (widget.grain == CalendarGrain.month) {
      return [
        _footBtn('本月', Palette.brandSoft, () {
          widget.onPickMonth?.call(_todayMonth);
          Navigator.of(context).pop();
        }),
      ];
    }
    return [
      _footBtn('今年', Palette.brandSoft, () {
        widget.onPickYear?.call(now.year);
        Navigator.of(context).pop();
      }),
    ];
  }

  Widget _footBtn(String label, Color bg, VoidCallback onTap) {
    final highlight = bg != Colors.transparent;
    return Material(
      color: highlight ? bg : const Color(0xFFFAF5EA),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          // 收窄：水平内边距 14 → 10、字号 12 → 11.5，宽度让给左侧图例
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.line),
          ),
          child: Text(label,
              style: serifStyle.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: highlight ? Palette.brand : Palette.textSub,
                  letterSpacing: 1)),
        ),
      ),
    );
  }
}
