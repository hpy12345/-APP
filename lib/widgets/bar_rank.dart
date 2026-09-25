import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 分类排行条形图（纯宽度动画，直译模拟版 renderBars）：
/// 金额降序 + 占比，条宽按最大值归一，动画 600ms easeOutCubic。
class BarRank extends StatelessWidget {
  final List<CategoryTotal> rows;
  final List<Color> colors;
  final Map<String, LedgerCategory> categoryMap;
  final int totalCents;

  const BarRank({
    super.key,
    required this.rows,
    required this.colors,
    required this.categoryMap,
    required this.totalCents,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text('本期暂无支出',
              style: TextStyle(fontSize: 13, color: Palette.textSub)),
        ),
      );
    }
    final maxCents = rows.first.cents == 0 ? 1 : rows.first.cents;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 15),
          _BarRow(
            row: rows[i],
            color: colors[i % colors.length],
            name: categoryMap[rows[i].categoryId]?.name ?? '未知',
            icon: categoryMap[rows[i].categoryId]?.icon ?? '📦',
            widthFactor: rows[i].cents / maxCents,
            pctText: totalCents == 0
                ? '0%'
                : '${(rows[i].cents / totalCents * 100).toStringAsFixed(1)}%',
          ),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final CategoryTotal row;
  final Color color;
  final String name;
  final String icon;
  final double widthFactor;
  final String pctText;

  const _BarRow({
    required this.row,
    required this.color,
    required this.name,
    required this.icon,
    required this.widthFactor,
    required this.pctText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(name,
                style: serifStyle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const Spacer(),
            Text('¥${fmtCents(row.cents)}',
                style: serifStyle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
            const SizedBox(width: 5),
            Text(pctText,
                style: const TextStyle(
                    fontSize: 11.5, color: Palette.textSub)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 9,
            color: const Color(0xFFEBE1CD),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widthFactor.clamp(0.0, 1.0).toDouble()),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
