import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 粒度段控（凹陷轨道 + 抬起选中块），两处共用同一套样式：
/// - 账单页：日 / 月
/// - 统计页：月 / 年
///
/// 之前两页各写一套（账单页用金浅底高亮、统计页用白卡抬起），
/// 视觉割裂 —— 统一到这里，改样式只改一处。
class GrainSwitch extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  /// 与左右相邻控件对齐的高度（账单页日期栏同为 40）
  static const double height = 40;
  static const double _cellWidth = 34;

  const GrainSwitch({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFECE2D0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _cell(i),
          ],
        ],
      ),
    );
  }

  Widget _cell(int i) {
    final on = selected == i;
    return GestureDetector(
      onTap: () => onChanged(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: _cellWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Palette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: on ? Border.all(color: const Color(0x4DB08D4F)) : null,
          boxShadow: on
              ? const [
                  BoxShadow(
                      color: Color(0x1F241E14),
                      offset: Offset(0, 1),
                      blurRadius: 3),
                ]
              : null,
        ),
        child: Text(labels[i],
            style: serifStyle.copyWith(
                fontSize: 12.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.5,
                color: on ? Palette.brand : Palette.textSub)),
      ),
    );
  }
}
