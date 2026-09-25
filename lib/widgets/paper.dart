import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 宣纸底：竖直暖白渐变 + 细密横纹（复刻模拟版 .screen 背景）。
/// 全局挂在 Scaffold 底层，子页面一律透明背景。
class PaperBackground extends StatelessWidget {
  final Widget child;
  const PaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PaperPainter(),
      child: child,
    );
  }
}

class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 竖直渐变：#fbf7ef → #f8f2e7(46%) → #f5efe3
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF7EF), Color(0xFFF8F2E7), Color(0xFFF5EFE3)],
          stops: [0.0, 0.46, 1.0],
        ).createShader(rect),
    );

    // 细密横纹：每 3.5 逻辑像素一条，rgba(150,126,92,.035)
    final line = Paint()..color = const Color(0x09967E5C);
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      y += 3.5;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) => false;
}

/// 通用面板容器：宣纸卡 + 标题（朱砂竖条 + 宋体 + 右侧说明）
class PanelCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const PanelCard({super.key, required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: paperCard(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                margin: const EdgeInsets.only(right: 9),
                decoration: BoxDecoration(
                  color: Palette.brand,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Expanded(
                child: Text(title,
                    style: serifStyle.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4)),
              ),
              if (trailing != null)
                Text(trailing!,
                    style: serifStyle.copyWith(
                        fontSize: 11.5, color: Palette.textSub)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
