import 'package:flutter/material.dart';

/// 金额自适应降字号（直译模拟版 fitAmount）：
/// 位数多的大额在窄卡里自动从 [max] 降到 [min]，不裁切。
///
/// 注意 `textScaler`：TextPainter 默认不套系统字号缩放，而 `Text` 会套。
/// 不传的话实测宽度偏小 —— 系统字号 1.3 倍时量出来只有实际的 77%，
/// 大额就“看起来放得下”，结果右边被裁掉。
class FitText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final TextStyle style;

  const FitText({
    super.key,
    required this.text,
    required this.maxFontSize,
    required this.minFontSize,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      var size = maxFontSize;
      while (size > minFontSize) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textScaler: scaler,
        )..layout();
        if (painter.width <= constraints.maxWidth) break;
        size -= 1;
      }
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: style.copyWith(fontSize: size));
    });
  }
}
