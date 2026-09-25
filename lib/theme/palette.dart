import 'package:flutter/material.dart';

/// 国风设计令牌 —— 与模拟版 `index.html` 的 CSS 变量一一对应。
/// 颜色集中定义（落地方案 3.3 主题系统），改主题只改这里。
class Palette {
  Palette._();

  // ── 底色 ──────────────────────────────────────────────
  static const Color bgPage = Color(0xFFE6DED0); // 页面背景（旧绢）
  static const Color screenBg = Color(0xFFF7F1E6); // 屏幕背景（宣纸）
  static const Color paper = Color(0xFFFBF7EF); // 宣纸亮面
  static const Color card = Color(0xFFFDFAF4); // 卡片

  // ── 文字 / 线 ────────────────────────────────────────
  static const Color text = Color(0xFF2B2521); // 主文字（浓墨）
  static const Color textSub = Color(0xFF8D8273); // 次要文字（淡墨）
  static const Color line = Color(0xFFE6DCC9); // 分割线（浅赭）

  // ── 主题 ──────────────────────────────────────────────
  static const Color brand = Color(0xFF9E4034); // 朱砂
  static const Color brandDeep = Color(0xFF7A2E26); // 深朱
  static const Color brandSoft = Color(0xFFF6E8E2); // 朱砂浅底
  static const Color gold = Color(0xFFB08D4F); // 描金
  static const Color goldSoft = Color(0xFFEFE2C8); // 金浅底
  static const Color ink = Color(0xFF22303C); // 黛青

  // ── 收支语义色（中国市场惯例：涨红跌绿 → 支出红 / 收入绿） ──
  static const Color expense = Color(0xFFB23A30); // 支出（朱砂红）
  static const Color income = Color(0xFF4A7C59); // 收入（青绿）

  // ── 键盘 ──────────────────────────────────────────────
  static const Color keyBg = Color(0xFFFDFAF4);
  static const Color keyActive = Color(0xFFEEE3D2);

  // ── 环形图配色（国风矿物色，与模拟版一致） ────────────────
  static const List<Color> chartColors = [
    Color(0xFF9E4034), Color(0xFFC07A3E), Color(0xFFB08D4F), Color(0xFF4A7C59),
    Color(0xFF3F6A76), Color(0xFF8D5A72), Color(0xFFA04A56), Color(0xFF6D7D5A),
    Color(0xFF8A7448), Color(0xFF5C6B8A), Color(0xFFB5654A), Color(0xFF6F8F7C),
  ];

  /// 借贷四分类（往来）
  static const List<String> debtCategories = ['lend', 'repay', 'borrow', 'collect'];
}

/// 宋体标题样式（Android 自动回退系统衬线字体；内嵌思源宋体见 pubspec 注释）
const TextStyle serifStyle = TextStyle(
  fontFamily: 'serif',
  color: Palette.text,
);

/// 宣纸卡片统一样式：暖白渐变 + 浅赭边 + 描金内框 + 柔影
BoxDecoration paperCard({BorderRadius? radius}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment(-0.3, -0.8),
      end: Alignment(0.2, 0.9),
      colors: [Color(0xFFFEFBF5), Color(0xFFFBF6EC)],
    ),
    border: Border.all(color: Palette.line),
    borderRadius: radius ?? BorderRadius.circular(8),
    boxShadow: const [
      BoxShadow(
        color: Color(0x14241E14), // 宣纸卡柔影（对应 rgba(80,60,40,.08)）
        offset: Offset(0, 2),
        blurRadius: 6,
      ),
    ],
  );
}
