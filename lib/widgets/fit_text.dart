import 'package:flutter/material.dart';

/// 金额自适应降字号（直译模拟版 fitAmount）：
/// 位数多的大额在窄卡里自动从 [max] 降到 [min]，不裁切。
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
    return LayoutBuilder(builder: (context, constraints) {
      var size = maxFontSize;
      while (size > minFontSize) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
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
