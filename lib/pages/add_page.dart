import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../viewmodel/ledger_view_model.dart';
import '../widgets/number_keyboard.dart';
import '../widgets/paper.dart';
import '../widgets/toast.dart';

/// 记账页（复刻模拟版 page-add）：
/// 收支段控 → 金额区 → 分类 → 备注/日期 → 书写预览条 → 自绘键盘。
/// 交互规则全部直译模拟版：小数 ≤2 位、整数 ≤9 位、前导 0 替换、
/// 保存后 340ms 回首页并定位到该账单所在日。
class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final vm = context.read<LedgerViewModel>();
    _noteCtrl = TextEditingController(text: vm.form.note);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();
    final form = vm.form;
    final isExpense = form.type == 'expense';

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 关掉自动上推：备注框会唤起系统软键盘，若开启 resize 会把
      // 自绘键盘（固定高度 247）与预览条一起挤压，窄屏/大字体下直接
      // RenderFlex overflow。这里让内容保持原位，键盘浮在其上即可
      // ——备注/日期两行位于屏幕上方约 1/3 处，不会被键盘遮挡。
      resizeToAvoidBottomInset: false,
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── 标题行 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text('记一笔',
                        style: serifStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3)),
                    const Spacer(),
                    Text(
                      '今天 ${fmtDateCn(todayInt())}',
                      style: serifStyle.copyWith(
                          fontSize: 12,
                          color: Palette.textSub,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),

              // ── 支出 / 收入 段控 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE2D0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.line),
                  ),
                  child: Row(
                    children: [
                      _segBtn('支出', 'expense', isExpense, Palette.expense),
                      const SizedBox(width: 5),
                      _segBtn('收入', 'income', !isExpense, Palette.income),
                    ],
                  ),
                ),
              ),

              // ── 金额区 ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.fromLTRB(19, 17, 19, 17),
                decoration: paperCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isExpense ? '支出金额' : '收入金额',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: Palette.textSub,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('¥',
                            style: serifStyle.copyWith(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: isExpense
                                    ? Palette.expense
                                    : Palette.income)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: _AmountDisplay(
                            buffer: form.buffer,
                            isExpense: isExpense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 分类（横向滚动） ──
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in vm.categories
                        .where((c) => c.type == form.type))
                      _CatButton(
                        category: c,
                        selected: c.id == form.categoryId,
                        onTap: () => vm.setFormCategory(c.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 备注 / 日期 ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: paperCard(),
                child: Column(
                  children: [
                    _metaRow(
                      label: '备注',
                      child: TextField(
                        controller: _noteCtrl,
                        maxLength: 20,
                        style: const TextStyle(fontSize: 15),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        // 点空白处收起系统键盘，露出被遮挡的自绘键盘
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          counterText: '',
                          hintText: '点击输入备注（选填）',
                          hintStyle: TextStyle(
                              fontSize: 15, color: Color(0xFFC2B7A2)),
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 16),
                      color: Palette.line,
                    ),
                    _metaRow(
                      label: '日期',
                      child: InkWell(
                        onTap: () => _pickDate(context, vm),
                        child: Row(
                          children: [
                            Text(
                              '${fmtDateDash(form.dateInt)}'
                              '  ${form.dateInt == todayInt() ? '今天' : weekLabel(form.dateInt)}',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const Spacer(),
                            const Icon(Icons.calendar_month_outlined,
                                size: 17, color: Palette.textSub),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 书写预览条（撑满中段留白） ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: _PreviewStrip(
                    buffer: form.buffer,
                    isExpense: isExpense,
                    categoryName:
                        vm.categoryMap[form.categoryId]?.name ?? '未选',
                    dateInt: form.dateInt,
                  ),
                ),
              ),

              // ── 键盘提示条 + 键盘 ──
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEFE6D6), Color(0xFFE9DFCC)],
                  ),
                  border: Border(top: BorderSide(color: Palette.line)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '已选「',
                          style: const TextStyle(
                              fontSize: 12, color: Palette.textSub),
                          children: [
                            TextSpan(
                              text:
                                  vm.categoryMap[form.categoryId]?.name ??
                                      '未选',
                              style: serifStyle.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1),
                            ),
                            const TextSpan(text: '」 · '),
                            TextSpan(
                                text: form.dateInt == todayInt()
                                    ? '今天'
                                    : fmtDateCn(form.dateInt)),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () {
                        vm.clearForm();
                        _noteCtrl.clear();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xB3FDFAF4),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Palette.line),
                        ),
                        child: Text('清空',
                            style: serifStyle.copyWith(
                                fontSize: 12.5,
                                color: Palette.textSub,
                                letterSpacing: 1.2)),
                      ),
                    ),
                  ],
                ),
              ),
              NumberKeyboard(
                onKey: vm.handleKey,
                onSave: () => _save(vm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segBtn(String label, String type, bool on, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<LedgerViewModel>().setFormType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: on
                ? const LinearGradient(
                    begin: Alignment(-0.3, -0.8),
                    end: Alignment(0.2, 0.9),
                    colors: [Color(0xFFFEFBF5), Color(0xFFFAF4E8)])
                : null,
            borderRadius: BorderRadius.circular(5),
            boxShadow: on
                ? const [
                    BoxShadow(
                        color: Color(0x33241E14),
                        offset: Offset(0, 1),
                        blurRadius: 2),
                    BoxShadow(
                        color: Color(0x1F241E14),
                        offset: Offset(0, 3),
                        blurRadius: 10),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: serifStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: on ? color : const Color(0xFFA1937E),
              )),
        ),
      ),
    );
  }

  Widget _metaRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(label,
                style: serifStyle.copyWith(
                    fontSize: 14,
                    color: Palette.textSub,
                    letterSpacing: 2)),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, LedgerViewModel vm) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dtOf(vm.form.dateInt),
      firstDate: DateTime(calendarMinYear),
      lastDate: now,
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) vm.setFormDate(dateIntOf(picked));
  }

  void _save(LedgerViewModel vm) {
    vm.setFormNote(_noteCtrl.text);
    final r = vm.saveBill();
    if (r == SaveResult.ok) {
      _noteCtrl.clear();
      showAppToast(context, '已保存');
      // 直译模拟版：保存后 340ms 回首页并定位该账单所在日
      Future.delayed(const Duration(milliseconds: 340), () {
        if (mounted) vm.switchTab(0);
      });
    } else {
      showAppToast(context,
          r == SaveResult.needAmount ? '请输入有效金额' : '请选择分类');
    }
  }
}

// ═══ 金额显示（占位 0 + 光标闪烁） ═════════════════════════

class _AmountDisplay extends StatelessWidget {
  final String buffer;
  final bool isExpense;

  const _AmountDisplay({required this.buffer, required this.isExpense});

  @override
  Widget build(BuildContext context) {
    final hasVal = buffer.isNotEmpty && buffer != '0';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            hasVal ? buffer : '0',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: serifStyle.copyWith(
              fontSize: 39,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              height: 47 / 39,
              color: hasVal ? Palette.text : const Color(0xFFCDC2AD),
            ),
          ),
        ),
        const _BlinkingCaret(),
      ],
    );
  }
}

/// 光标闪烁（模拟版 caret 1s 步进）
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret> {
  late final Timer _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 60),
      child: Container(
        width: 2,
        height: 30,
        margin: const EdgeInsets.only(left: 2, bottom: 4),
        color: Palette.brand,
      ),
    );
  }
}

// ═══ 分类按钮 ═════════════════════════════════════════════

class _CatButton extends StatelessWidget {
  final LedgerCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CatButton(
      {required this.category,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              transform: Matrix4.translationValues(
                  0, selected ? -2 : 0, 0),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: category.bgColor,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: selected ? Palette.brand : Palette.line),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                            color: Color(0x579E4034),
                            offset: Offset(0, 4),
                            blurRadius: 12),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(category.icon,
                  style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: serifStyle.copyWith(
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Palette.brand : Palette.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ 书写预览条（国风题签） ═══════════════════════════════

class _PreviewStrip extends StatelessWidget {
  final String buffer;
  final bool isExpense;
  final String categoryName;
  final int dateInt;

  const _PreviewStrip({
    required this.buffer,
    required this.isExpense,
    required this.categoryName,
    required this.dateInt,
  });

  @override
  Widget build(BuildContext context) {
    final hasVal = buffer.isNotEmpty && buffer != '0';
    final dateTxt = dateInt == todayInt() ? '今天' : fmtDateCn(dateInt);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0x73B08D4F), style: BorderStyle.solid),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3FDFAF4), Color(0x80F7F1E6)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 朱砂题签
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.5),
                radius: 0.9,
                colors: [
                  Color(0xFFB8544A),
                  Color(0xFF9E4034),
                  Color(0xFF7F2F26)
                ],
                stops: [0.0, 0.6, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x618D3227),
                    offset: Offset(0, 2),
                    blurRadius: 7),
              ],
            ),
            alignment: Alignment.center,
            child: Text('记',
                style: serifStyle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Palette.goldSoft)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: hasVal
                ? Text.rich(
                    TextSpan(
                      style: serifStyle.copyWith(
                          fontSize: 13,
                          color: Palette.textSub,
                          letterSpacing: 1.2),
                      children: [
                        TextSpan(
                          text:
                              '${isExpense ? '-' : '+'} ¥$buffer',
                          style: serifStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isExpense
                                ? Palette.expense
                                : Palette.income,
                          ),
                        ),
                        const TextSpan(text: '  ·  '),
                        TextSpan(text: categoryName),
                        const TextSpan(text: '  ·  '),
                        TextSpan(text: dateTxt),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : Text('尚未输入金额',
                    style: serifStyle.copyWith(
                        fontSize: 13,
                        color: Palette.textSub,
                        letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }
}
