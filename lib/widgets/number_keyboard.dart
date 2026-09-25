import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';

/// 自绘数字键盘（复刻模拟版 .keyboard 布局）：
///
/// ```
/// 1  2  3  [退格]
/// 4  5  6  [保存]   ← 跨两行（朱砂印章）
/// 7  8  9  ↑
/// ·  0  今天
/// ```
///
/// 键值：'0'-'9' / '.' / 'back' / 'save' / 'today'
/// 交互：按键触感反馈（HapticFeedback）+ 长按退格连删（落地方案 2.3 体验打磨）
class NumberKeyboard extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onSave;

  const NumberKeyboard({super.key, required this.onKey, required this.onSave});

  static const double gap = 7;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE6D6), Color(0xFFE9DFCC)],
        ),
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 4 列等宽（对齐模拟版 grid-template-columns: repeat(4, 1fr)）
          final kw = (constraints.maxWidth - gap * 3) / 4;
          const kh = 52.0;
          Widget box(String k, {bool fn = false, String? label, double? fs}) =>
              SizedBox(
                width: kw,
                height: kh,
                child: _Key(
                  label: label ?? k,
                  fn: fn,
                  fontSize: fs ?? (fn && (label ?? k).length > 1 ? 15 : 23),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onKey(k);
                  },
                ),
              );
          const spacer = SizedBox(width: gap);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 行 1：1 2 3 退格
              Row(children: [
                box('1'), spacer, box('2'), spacer, box('3'), spacer,
                SizedBox(
                    width: kw, height: kh, child: _BackKey(onBack: () => onKey('back'))),
              ]),
              const SizedBox(height: gap),
              // 行 2-4：左侧九宫格，右侧跨 3 行「保存」
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Row(children: [box('4'), spacer, box('5'), spacer, box('6')]),
                      const SizedBox(height: gap),
                      Row(children: [box('7'), spacer, box('8'), spacer, box('9')]),
                      const SizedBox(height: gap),
                      Row(children: [
                        box('.', fn: true, label: '·'),
                        spacer,
                        box('0'),
                        spacer,
                        box('today', fn: true, label: '今天'),
                      ]),
                    ],
                  ),
                  spacer,
                  SizedBox(
                      width: kw,
                      height: kh * 3 + gap * 2,
                      child: _SaveKey(onSave: onSave)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 普通按键（视觉 + 点击）
class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool fn;
  final double fontSize;
  final Widget? child;

  const _Key({
    required this.label,
    required this.onTap,
    this.fn = false,
    this.fontSize = 23,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fn ? const Color(0xFFEBE1CF) : Palette.keyBg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE0D5BF)),
            boxShadow: const [
              BoxShadow(color: Color(0x2E78603C), offset: Offset(0, 1.5)),
            ],
          ),
          alignment: Alignment.center,
          child: child ??
              Text(label,
                  style: serifStyle.copyWith(
                      fontSize: fontSize, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// 退格键：点击退一格，长按连删
class _BackKey extends StatefulWidget {
  final VoidCallback onBack;
  const _BackKey({required this.onBack});

  @override
  State<_BackKey> createState() => _BackKeyState();
}

class _BackKeyState extends State<_BackKey> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.selectionClick();
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        _timer = Timer.periodic(
            const Duration(milliseconds: 80), (_) => widget.onBack());
      },
      onLongPressEnd: (_) => _timer?.cancel(),
      onLongPressCancel: () => _timer?.cancel(),
      child: _Key(
        label: '',
        fn: true,
        onTap: _tap,
        child: const Icon(Icons.backspace_outlined,
            size: 24, color: Palette.textSub),
      ),
    );
  }
}

/// 保存键：朱砂印章，高度由外层 SizedBox 给定（跨 3 行）
class _SaveKey extends StatelessWidget {
  final VoidCallback onSave;
  const _SaveKey({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.mediumImpact();
          onSave();
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFA84A3C), Color(0xFF8A3229)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(6)),
            border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF7A2E26))),
            boxShadow: [
              BoxShadow(
                  color: Color(0x577E2E26), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          alignment: Alignment.center,
          child: Text('保 存',
              style: serifStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFDF6EC),
                  letterSpacing: 2)),
        ),
      ),
    );
  }
}
