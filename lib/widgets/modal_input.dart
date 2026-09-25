import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';

/// 可编辑数字弹层（预算设置）—— 复刻模拟版 modal：
/// 输入过滤（数字 + 单小数点 + 2 位小数）· 快捷金额档 · 描金内框。
///
/// 返回值：单位「分」；null = 取消；0 = 确定但清空（表示不设预算）。
Future<int?> showAmountInputDialog(
  BuildContext context, {
  required String title,
  required String tip,
  String initial = '',
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '取消',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondary) => _AmountInputDialog(
      title: title,
      tip: tip,
      initial: initial,
    ),
  );
}

class _AmountInputDialog extends StatefulWidget {
  final String title;
  final String tip;
  final String initial;

  const _AmountInputDialog({
    required this.title,
    required this.tip,
    required this.initial,
  });

  @override
  State<_AmountInputDialog> createState() => _AmountInputDialogState();
}

class _AmountInputDialogState extends State<_AmountInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 输入过滤，直译模拟版 modalInput 的 input 事件处理
  void _onChanged(String v) {
    var text = v.replaceAll(RegExp(r'[^\d.]'), '');
    final dot = text.indexOf('.');
    if (dot >= 0) {
      // 去掉第二个小数点，并限制 2 位小数（注意 Dart substring 越界会抛异常）
      final tail = text.substring(dot + 1).replaceAll('.', '');
      text = text.substring(0, dot + 1) +
          (tail.length > 2 ? tail.substring(0, 2) : tail);
    }
    if (text != v) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _confirm() {
    final v = double.tryParse(_controller.text.trim());
    Navigator.of(context).pop(v == null ? 0 : (v * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(1), // 描金外边
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.paper, Palette.card]),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Palette.gold),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.paper, Palette.card]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: serifStyle.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2)),
              const SizedBox(height: 4),
              Text(widget.tip,
                  style: const TextStyle(
                      fontSize: 12, color: Palette.textSub, height: 1.5)),
              const SizedBox(height: 14),
              // 输入框
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Palette.card,
                  border: Border.all(color: Palette.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('¥',
                        style: serifStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Palette.gold)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        onChanged: _onChanged,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        style: serifStyle.copyWith(
                            fontSize: 26, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(color: Color(0xFFC2B7A2)),
                        ),
                        onSubmitted: (_) => _confirm(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 快捷金额
              Row(
                children: [
                  for (final q in const ['1000', '2000', '3000', '5000'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: q == '5000' ? 0 : 8.0),
                        child: _QuickChip(
                            label: '¥$q',
                            onTap: () {
                              _controller.text = q;
                              _focus.requestFocus();
                            }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 操作
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Palette.card,
                        side: const BorderSide(color: Palette.line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('取消',
                          style: serifStyle.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Palette.textSub)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: _confirm,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF9A3E32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('确定',
                          style: serifStyle.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Palette.goldSoft)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(vertical: 9),
        minimumSize: Size.zero,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label,
            style: serifStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Palette.textSub)),
      ),
    );
  }
}
