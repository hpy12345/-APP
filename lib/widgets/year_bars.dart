import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 年视图：12 个月支出 / 收入双柱图（直译模拟版 renderYearChart）。
/// 高度按全年峰值归一，当月朱砂下划线标记，高度动画 550ms。
///
/// 点任意一列 → 选中该月，柱子加朱砂浅底高亮，下方读出条给出该月
/// 支出 / 收入的具体金额。默认选中峰值月（全年无记账时落在当月），
/// 所以读出条任何时候都有内容，不需要「点一下试试」的提示文案。
class YearBars extends StatefulWidget {
  final List<MonthSum> months; // 长度 12
  final int year;

  const YearBars({super.key, required this.months, required this.year});

  @override
  State<YearBars> createState() => _YearBarsState();
}

class _YearBarsState extends State<YearBars> {
  late int _sel;

  @override
  void initState() {
    super.initState();
    _sel = _defaultIndex();
  }

  @override
  void didUpdateWidget(covariant YearBars old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) _sel = _defaultIndex();
  }

  /// 默认选中：峰值月；全年为空则落在当月（看的不是当年 → 1 月）
  int _defaultIndex() {
    var best = -1;
    var bestVal = 0;
    for (var i = 0; i < widget.months.length; i++) {
      final v = math.max(widget.months[i].expense, widget.months[i].income);
      if (v > bestVal) {
        bestVal = v;
        best = i;
      }
    }
    if (best >= 0) return best;
    final now = DateTime.now();
    return widget.year == now.year ? now.month - 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    var max = 1;
    for (final m in widget.months) {
      if (m.expense > max) max = m.expense;
      if (m.income > max) max = m.income;
    }
    final now = DateTime.now();
    final sel = widget.months[_sel];

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 12; i++)
                Expanded(
                  child: _MonthCol(
                    sum: widget.months[i],
                    max: max,
                    isCurrent: widget.year == now.year && i + 1 == now.month,
                    selected: i == _sel,
                    onTap: () => setState(() => _sel = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 月份标签行
        Row(
          children: [
            for (var i = 1; i <= 12; i++)
              Expanded(
                child: Text('$i',
                    textAlign: TextAlign.center,
                    style: serifStyle.copyWith(
                        fontSize: 10.5,
                        color: i - 1 == _sel
                            ? Palette.brand
                            : (widget.year == now.year && i == now.month)
                                ? Palette.brand
                                : Palette.textSub,
                        fontWeight: (i - 1 == _sel ||
                                (widget.year == now.year && i == now.month))
                            ? FontWeight.w700
                            : FontWeight.w400)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthReadout(month: _sel + 1, sum: sel),
      ],
    );
  }
}

/// 选中月份的读数条（点柱子后看这里的具体值）。
///
/// 布局：支出、收入各占一行，月份居中夹在两行中央（两侧描金短线）——
/// 三个信息挤一行时，大字号下两个金额都会被迫省略号，分行后每行都能给足宽度。
class _MonthReadout extends StatelessWidget {
  final int month;
  final MonthSum sum;

  const _MonthReadout({required this.month, required this.sum});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EEE1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        children: [
          _row('支出', sum.expense, Palette.expense),
          _monthLine(),
          _row('收入', sum.income, Palette.income),
        ],
      ),
    );
  }

  Widget _row(String label, int cents, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: serifStyle.copyWith(
                fontSize: 12, color: Palette.textSub, letterSpacing: 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('¥${fmtCents(cents)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: serifStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2)),
        ),
      ],
    );
  }

  /// 月份行：居中，两侧各一条描金短线
  Widget _monthLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, color: Color(0x4DB08D4F))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$month 月',
                style: serifStyle.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Palette.brand)),
          ),
          const Expanded(child: Divider(height: 1, color: Color(0x4DB08D4F))),
        ],
      ),
    );
  }
}

class _MonthCol extends StatelessWidget {
  final MonthSum sum;
  final int max;
  final bool isCurrent;
  final bool selected;
  final VoidCallback onTap;

  const _MonthCol({
    required this.sum,
    required this.max,
    required this.isCurrent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 整列都可点（含柱子上方的空白），否则只有细柱子能点到，手感很差
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: selected
            ? BoxDecoration(
                color: const Color(0x149E4034),
                borderRadius: BorderRadius.circular(5),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Bar(
                      cents: sum.expense,
                      max: max,
                      gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFC9503F), Color(0xFF8D3227)])),
                  const SizedBox(width: 2),
                  _Bar(
                      cents: sum.income,
                      max: max,
                      gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6D9D76), Color(0xFF3F6A4C)])),
                ],
              ),
            ),
            // 当月朱砂下划线（选中态由整列底色表达，两者可叠加）
            Container(
              height: 2,
              margin: const EdgeInsets.only(top: 2),
              color: isCurrent
                  ? const Color(0x809E4034)
                  : (selected ? const Color(0x339E4034) : Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int cents;
  final int max;
  final LinearGradient gradient;

  const _Bar({required this.cents, required this.max, required this.gradient});

  @override
  Widget build(BuildContext context) {
    // 高度百分比：留 4% 底部余量；0 值不画线（直译模拟版）
    final h = cents > 0
        ? (cents / max * 96).clamp(2.0, 96.0).toDouble()
        : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: h / 100),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => FractionallySizedBox(
        heightFactor: v,
        child: Container(
          width: 9,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

/// 年视图图例（支出红 / 收入绿）
class YearLegend extends StatelessWidget {
  const YearLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          const Divider(height: 1, color: Palette.line),
          const SizedBox(height: 12),
          Row(
            children: [
              _item(Palette.expense, '支出'),
              const SizedBox(width: 16),
              _item(Palette.income, '收入'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: serifStyle.copyWith(
                fontSize: 11.5, color: Palette.textSub, letterSpacing: 0.8)),
      ],
    );
  }
}
