import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 环形图（CustomPainter 直译模拟版 drawDonut）：
/// - 起始角 −90°（12 点方向），顺时针
/// - 扇区缝 0.028 rad
/// - 单段 100% 不留缝
/// - 空数据画浅色整环
///
/// v2.0.0：右侧图例删掉了，占比明细挪到图**下方**的排行列表（`BarRank`），
/// 这里成了整块区域的主角 —— 直径 150 → 200、环宽 23 → 26，环心文字同比放大。
class DonutChart extends StatelessWidget {
  /// 直径。卡片内宽 296（360 − 页面 32 − 卡片 32），200 居中后左右各留 48。
  static const double size = 200;

  /// 环宽（逻辑像素）
  static const double thickness = 26;

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
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _DonutPainter(
                rows: rows, colors: colors, total: totalCents),
          ),
          // 环心文字：宽度收紧 + scaleDown 兜底，大额（¥12.3万）也不会顶出环外
          SizedBox(
            width: 112,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('总支出',
                      style: serifStyle.copyWith(
                          fontSize: 12,
                          color: Palette.textSub,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('¥${fmtCentsShort(totalCents)}',
                      style: serifStyle.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Palette.expense,
                          letterSpacing: -0.3)),
                ],
              ),
            ),
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
    final radius = size.width / 2 - 6;
    const thick = DonutChart.thickness;
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

    const gap = 0.028; // 扇形之间的缝隙（弧度）
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
// 注：原来这里还有一个 DonutLegend（环形图右侧的图例列表）。
// v2.0.0 把「占比明细」整体挪到环形图下方（BarRank 排行列表），
// 右侧内容按用户要求删掉，图例组件随之删除。
