import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 环形图（CustomPainter 直译模拟版 drawDonut）：
/// - 起始角 −90°（12 点方向），顺时针
/// - 扇区缝 0.028 rad，环宽 23 逻辑像素（= 模拟版 46@2x）
/// - 单段 100% 不留缝
/// - 空数据画浅色整环
class DonutChart extends StatelessWidget {
  final List<CategoryTotal> rows;
  final List<Color> colors;
  final int totalCents;

  const DonutChart({
    super.key,
    required this.rows,
    required this.colors,
    required this.totalCents,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(168, 168),
            painter: _DonutPainter(rows: rows, colors: colors, total: totalCents),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('总支出',
                  style: serifStyle.copyWith(
                      fontSize: 11,
                      color: Palette.textSub,
                      letterSpacing: 2)),
              const SizedBox(height: 3),
              Text('¥${fmtCentsShort(totalCents)}',
                  style: serifStyle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Palette.expense,
                      letterSpacing: -0.3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategoryTotal> rows;
  final List<Color> colors;
  final int total;

  _DonutPainter({required this.rows, required this.colors, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6; // 对应模拟版 R = 336/2 - 12（@2x）
    const thick = 23.0; // 对应模拟版 46@2x
    final arcRadius = radius - thick / 2;
    final rect = Rect.fromCircle(center: center, radius: arcRadius);

    if (total == 0 || rows.isEmpty) {
      // 空状态：一圈浅灰
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick
        ..color = const Color(0xFFF0E8D8);
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    final gap = 0.028; // 扇形之间的缝隙（弧度）
    var start = -math.pi / 2; // 12 点方向起始

    for (var i = 0; i < rows.length; i++) {
      final ratio = rows[i].cents / total;
      final sweep = ratio * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick
        ..strokeCap = StrokeCap.butt
        ..color = colors[i % colors.length];

      final s = rows.length > 1 ? start + gap / 2 : start;
      final e = rows.length > 1
          ? math.max(s, start + sweep - gap / 2)
          : start + sweep;
      canvas.drawArc(rect, s, e - s, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.rows != rows || old.total != total || old.colors != colors;
}

/// 环形图右侧图例（前 6，直译模拟版 renderLegend）
class DonutLegend extends StatelessWidget {
  final List<CategoryTotal> rows;
  final List<Color> colors;
  final Map<String, LedgerCategory> categoryMap;
  final int totalCents;

  const DonutLegend({
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
        child: Text('本月暂无支出',
            style: TextStyle(fontSize: 13, color: Palette.textSub)),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length && i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categoryMap[rows[i].categoryId]?.name ?? '未知',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: serifStyle.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6),
                  ),
                ),
                Text(
                  totalCents == 0
                      ? '0%'
                      : '${(rows[i].cents / totalCents * 100).toStringAsFixed(1)}%',
                  style: serifStyle.copyWith(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 58,
                  child: Text(
                    '¥${fmtCentsShort(rows[i].cents)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11.5, color: Palette.textSub),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
