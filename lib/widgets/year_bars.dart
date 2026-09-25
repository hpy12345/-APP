import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../theme/palette.dart';

/// 年视图：12 个月支出 / 收入双柱图（直译模拟版 renderYearChart）。
/// 高度按全年峰值归一，当月朱砂下划线标记，高度动画 550ms。
class YearBars extends StatelessWidget {
  final List<MonthSum> months; // 长度 12
  final int year;

  const YearBars({super.key, required this.months, required this.year});

  @override
  Widget build(BuildContext context) {
    var max = 1;
    for (final m in months) {
      if (m.expense > max) max = m.expense;
      if (m.income > max) max = m.income;
    }
    final now = DateTime.now();

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
                    month: i + 1,
                    sum: months[i],
                    max: max,
                    isCurrent: year == now.year && i + 1 == now.month,
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
                        color: year == now.year && i == now.month
                            ? Palette.brand
                            : Palette.textSub,
                        fontWeight: year == now.year && i == now.month
                            ? FontWeight.w700
                            : FontWeight.w400)),
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthCol extends StatelessWidget {
  final int month;
  final MonthSum sum;
  final int max;
  final bool isCurrent;

  const _MonthCol({
    required this.month,
    required this.sum,
    required this.max,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
        // 当月朱砂下划线
        Container(
          height: 2,
          margin: const EdgeInsets.only(top: 2),
          color: isCurrent ? const Color(0x809E4034) : Colors.transparent,
        ),
      ],
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
