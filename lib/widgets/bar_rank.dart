import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 分类占比排行（金额降序）。
///
/// 每行两段：
/// ```
/// 🚗 交通                    ¥1,425.88   55.6%
/// ████████████████████████░░░░░░░░░░░░░░░░░░
/// ```
/// 第一段「图标 + 名称 + 金额 + 占比」：占比放进**固定宽度**的右对齐盒子里，
/// 于是所有金额、所有占比各自成一列（旧版占比宽度随文字变，金额列跟着参差）。
/// 第二段是整行宽的百分比条：**左对齐、长度 = 占比**，右端与上面占比数字的
/// 右边缘对齐 —— 条和数字量的是同一条基准，不会出现「条居中飘在中间、
/// 数字贴在最右」那种错位。
class BarRank extends StatelessWidget {
  /// 占比列的固定宽度（"100.0%" 在 1.3 倍字号下约 50px，留一点余量）
  static const double _pctWidth = 54;

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
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('本期暂无支出',
              style: TextStyle(fontSize: 13, color: Palette.textSub)),
        ),
      );
    }
    // 条长按**总额**归一（不是按最大值）：
    // 这样 55.6% 的条正好占轨道的 55.6%，条长与右边那个百分比数字说的是同一件事。
    // 旧版按最大值归一 → 最大那笔占满 100% 宽却写着 55.6%，视觉上就「对不上」。
    final total = totalCents <= 0 ? 1 : totalCents;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _BarRow(
            row: rows[i],
            color: colors[i % colors.length],
            name: categoryMap[rows[i].categoryId]?.name ?? '未知',
            icon: categoryMap[rows[i].categoryId]?.icon ?? '📦',
            widthFactor: rows[i].cents / total,
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
      // 必须是 start：Column 默认 center 会把百分比条居中摆放，
      // 旧版看起来「条飘在中间、和数字对不上」就是这里漏了 crossAxisAlignment。
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: serifStyle.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Text('¥${fmtCents(row.cents)}',
                style: serifStyle.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
            const SizedBox(width: 8),
            // 固定宽度 + scaleDown：系统字号继续放大时数字整体缩一点，
            // 也不会把金额列挤歪
            SizedBox(
              width: BarRank._pctWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(pctText,
                    style: serifStyle.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.textSub)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        // 百分比条：整行宽（右端 = 上面占比数字的右缘），填充长度 = 占比
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 9,
            width: double.infinity,
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
