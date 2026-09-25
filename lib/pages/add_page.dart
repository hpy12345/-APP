import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/dates.dart';
import '../viewmodel/ledger_view_model.dart';
import '../widgets/paper.dart';
import '../widgets/toast.dart';

/// 记账页（复刻模拟版 page-add）：
/// 收支段控 → 金额（系统数字键盘）→ 分类 → 备注 / 日期 → 已选条 + 保存。
///
/// ## 为什么不再用自绘键盘（v1.1.0 的决定）
/// 自绘键盘是一块固定 247 逻辑像素高的控件，加上段控 / 金额卡 / 分类 / 备注日期
/// 这几块固定内容后，整页高度是个常量；而**系统字号是用户可调的**：
/// 360×768 的机器在 1.3 倍字号下固定内容就涨到 ≈727，超过可用高度，
/// Column 只能把最后一行裁掉 —— 真机表现就是「键盘最下一排被标签栏切掉、
/// 悬浮球压在 0/今天 上」。任何「固定高度 + 固定内容」的方案都会在某档字号下
/// 溢出。改用系统数字键盘后，输入区高度不再由本页决定，键盘由系统绘制、
/// 永远不会被本页布局裁剪，这一类问题从根上消失。
class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  late final TextEditingController _noteCtrl;
  late final TextEditingController _amountCtrl;
  final FocusNode _amountFocus = FocusNode();
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<LedgerViewModel>();
    _noteCtrl = TextEditingController(text: vm.form.note);
    _amountCtrl = TextEditingController(text: vm.form.buffer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 切进记账页时自动聚焦金额框（系统键盘随即弹出，省掉一次点击）。
    // 只在「刚切进来」那一帧做：切回账单页后 _wasActive 复位，
    // 用户在页内手动收起键盘不会被强行唤起。
    final active = context.read<LedgerViewModel>().currentTab == 1;
    if (active && !_wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
    _wasActive = active;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();
    // 表单变化（金额、分类、日期）只订阅 formRev —— 这类高频变化不该把
    // 首页与统计页一起拖着重建。
    return ValueListenableBuilder<int>(
      valueListenable: vm.formRev,
      builder: (context, _, __) => _body(context, vm),
    );
  }

  Widget _body(BuildContext context, LedgerViewModel vm) {
    final isExpense = vm.form.type == 'expense';

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 与首页/统计页相反：本页现在用系统键盘，**必须**让 Scaffold 依据
      // viewInsets 收窄 body —— 底部的保存按钮才能始终贴在键盘上沿。
      resizeToAvoidBottomInset: true,
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              _titleBar(),
              // 键盘弹起后剩余高度有限：上方内容可滚动，任何字号下都不会被裁
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: [
                      _segSwitch(isExpense),
                      _amountCard(vm, isExpense),
                      _categoryRow(vm),
                      const SizedBox(height: 9),
                      _metaCard(vm),
                    ],
                  ),
                ),
              ),
              _bottomBar(vm),
            ],
          ),
        ),
      ),
    );
  }

  // ── 标题行 ──
  Widget _titleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        children: [
          Text('记一笔',
              style: serifStyle.copyWith(
                  fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 3)),
          const Spacer(),
          Text('今天 ${fmtDateCn(todayInt())}',
              style: serifStyle.copyWith(
                  fontSize: 12, color: Palette.textSub, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ── 支出 / 收入 段控 ──
  Widget _segSwitch(bool isExpense) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Container(
        height: 46,
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
    );
  }

  // ── 金额区 ──
  Widget _amountCard(LedgerViewModel vm, bool isExpense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
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
          const SizedBox(height: 2),
          _AmountField(
            controller: _amountCtrl,
            focusNode: _amountFocus,
            isExpense: isExpense,
            onChanged: vm.setFormBuffer,
          ),
        ],
      ),
    );
  }

  // ── 分类（横向滚动） ──
  // 顶部留 5px：选中态图标会上移 2px，ListView 视口不裁剪就会切掉上边框
  Widget _categoryRow(LedgerViewModel vm) {
    final type = vm.form.type;
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
        children: [
          for (final c in vm.categories.where((c) => c.type == type))
            _CatButton(
              category: c,
              selected: c.id == vm.form.categoryId,
              onTap: () => vm.setFormCategory(c.id),
            ),
        ],
      ),
    );
  }

  // ── 备注 / 日期 ──
  Widget _metaCard(LedgerViewModel vm) {
    final form = vm.form;
    final isToday = form.dateInt == todayInt();
    return Container(
      decoration: paperCard(),
      child: Column(
        children: [
          _metaRow(
            label: '备注',
            child: TextField(
              controller: _noteCtrl,
              maxLength: 20,
              style: const TextStyle(fontSize: 14.5),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: '点击输入备注（选填）',
                hintStyle: TextStyle(fontSize: 14.5, color: Color(0xFFC2B7A2)),
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
            // 整行可点：打开系统日期选择器
            child: InkWell(
              onTap: () => _pickDate(context, vm),
              child: Row(
                children: [
                  Text(
                    fmtDateDash(form.dateInt),
                    style: const TextStyle(fontSize: 14.5),
                  ),
                  const SizedBox(width: 8),
                  Text(isToday ? '今天' : weekLabel(form.dateInt),
                      style: const TextStyle(
                          fontSize: 14.5, color: Palette.textSub)),
                  const Spacer(),
                  // 「今天」快捷（原自绘键盘上的 today 键，改用系统键盘后挪到这里）
                  if (!isToday)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        vm.setFormDate(todayInt());
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Palette.goldSoft,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0x6BB08D4F)),
                        ),
                        child: Text('今天',
                            style: serifStyle.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Palette.gold)),
                      ),
                    ),
                  const Icon(Icons.calendar_month_outlined,
                      size: 17, color: Palette.textSub),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 底栏：已选摘要 + 清空 + 保存 ──
  Widget _bottomBar(LedgerViewModel vm) {
    final form = vm.form;
    final cat = vm.categoryMap[form.categoryId]?.name ?? '未选';
    final dateTxt = form.dateInt == todayInt() ? '今天' : fmtDateCn(form.dateInt);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE6D6), Color(0xFFE9DFCC)],
        ),
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '已选「',
                style: const TextStyle(fontSize: 12, color: Palette.textSub),
                children: [
                  TextSpan(
                    text: cat,
                    style: serifStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                  const TextSpan(text: '」 · '),
                  TextSpan(text: dateTxt),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _plainChip('清空', () {
            vm.clearForm();
            _noteCtrl.clear();
            _amountCtrl.clear();
          }),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            height: 44,
            child: _SaveSeal(onTap: () => _save(vm)),
          ),
        ],
      ),
    );
  }

  Widget _plainChip(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xB3FDFAF4),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Palette.line),
        ),
        child: Text(label,
            style: serifStyle.copyWith(
                fontSize: 12.5, color: Palette.textSub, letterSpacing: 1.2)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: serifStyle.copyWith(
                    fontSize: 13.5,
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
    final picked = await showDatePicker(
      context: context,
      initialDate: dtOf(vm.form.dateInt),
      firstDate: DateTime(calendarMinYear),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) vm.setFormDate(dateIntOf(picked));
  }

  void _save(LedgerViewModel vm) {
    vm.setFormNote(_noteCtrl.text);
    final r = vm.saveBill();
    if (r == SaveResult.ok) {
      _noteCtrl.clear();
      _amountCtrl.clear();
      FocusScope.of(context).unfocus();
      showAppToast(context, '已保存');
      // 直译模拟版：保存后 340ms 回首页并定位该账单所在日
      Future.delayed(const Duration(milliseconds: 340), () {
        if (mounted) vm.switchTab(0);
      });
    } else if (r == SaveResult.needAmount) {
      _amountFocus.requestFocus();
      showAppToast(context, '请输入有效金额');
    } else {
      showAppToast(context, '请选择分类');
    }
  }
}

// ═══ 金额输入（系统数字键盘） ═══════════════════════════════

/// 金额输入框。
///
/// 三件事：
/// ① 位数约束交给 [_AmountInputFormatter]（整数 ≤9 / 小数 ≤2 / 前导 0 替换），
///    与模拟版 handleKey 的数字规则逐条对齐；
/// ② 长金额等比降字号（原先靠模拟版的 fitAmount），按当前文本实测宽度算；
/// ③ `¥` 用 `InputDecoration.prefixText` —— 由框架按输入框基线摆放。
///    旧版是自己在 Stack 里量基线定位，而 TextPainter 默认不套 `textScaler`：
///    系统字号 ≠ 1 时量出的是「未放大」的宽度/基线，于是光标落进数字里
///    （输入后与数字重叠）、竖向也错位 —— 这就是那个 bug 的根因。
class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isExpense;
  final ValueChanged<String> onChanged;

  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.isExpense,
    required this.onChanged,
  });

  static const double _digitMax = 39;
  static const double _digitMin = 20;
  static const double _lineHeight = 47;
  static const double _yenSize = 25;
  static const double _yenGap = 5;
  static const Color _placeholder = Color(0xFFCDC2AD);

  TextStyle _digitStyle(double fs, Color color) => serifStyle.copyWith(
        fontSize: fs,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: _lineHeight / _digitMax,
        color: color,
      );

  double _width(String text, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, c) {
      final raw = controller.text;
      final hasVal = raw.isNotEmpty && raw != '0';
      final color = hasVal ? Palette.text : _placeholder;

      final yenStyle = serifStyle.copyWith(
        fontSize: _yenSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: _lineHeight / _digitMax,
        color: isExpense ? Palette.expense : Palette.income,
      );

      var fs = _digitMax;
      final yenW = _width('¥', yenStyle, scaler) + _yenGap;
      final avail = c.maxWidth - yenW - 2;
      final shown = raw.isEmpty ? '0' : raw;
      final w = _width(shown, _digitStyle(fs, color), scaler);
      if (avail > 0 && w > avail) {
        fs = (fs * avail / w).floorToDouble().clamp(_digitMin, _digitMax);
      }

      return TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [_AmountInputFormatter()],
        onChanged: onChanged,
        style: _digitStyle(fs, color),
        cursorColor: Palette.brand,
        cursorWidth: 2,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          prefixText: '¥',
          prefixStyle: yenStyle,
          hintText: '0',
          hintStyle: _digitStyle(fs, _placeholder),
        ),
      );
    });
  }
}

/// 金额输入约束（直译模拟版 handleKey 的数字规则）：
/// 只收数字与 1 个小数点；整数 ≤9 位、小数 ≤2 位；前导 0 被替换。
class _AmountInputFormatter extends TextInputFormatter {
  const _AmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    // 只保留第一个小数点
    final firstDot = t.indexOf('.');
    if (firstDot >= 0) {
      t = t.substring(0, firstDot + 1) +
          t.substring(firstDot + 1).replaceAll('.', '');
    }
    // 前导 0 替换：'0' 后继续输入数字 → 丢掉那个 0（'0' / '0.' 例外）
    if (t.length > 1 && t[0] == '0' && t[1] != '.') {
      t = t.substring(1);
    }
    // 位数上限
    final dot = t.indexOf('.');
    if (dot >= 0) {
      final intPart = t.substring(0, dot);
      final dec = t.substring(dot + 1);
      if (intPart.length > 9 || dec.length > 2) return oldValue;
      if (intPart.isEmpty) t = '0$t'; // '.5' → '0.5'
    } else if (t.length > 9) {
      return oldValue;
    }

    if (t == newValue.text) return newValue;
    // 长度变化时按同样的增量平移光标，避免中间插删时光标跳到末尾
    final delta = t.length - newValue.text.length;
    final offset =
        (newValue.selection.baseOffset + delta).clamp(0, t.length).toInt();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// 保存键：朱砂印章（原自绘键盘上的保存键，现在固定在底栏）
class _SaveSeal extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveSeal({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFA84A3C), Color(0xFF8A3229)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(6)),
            border:
                Border.fromBorderSide(BorderSide(color: Color(0xFF7A2E26))),
            boxShadow: [
              BoxShadow(
                  color: Color(0x577E2E26),
                  offset: Offset(0, 2),
                  blurRadius: 8),
            ],
          ),
          alignment: Alignment.center,
          child: Text('保 存',
              style: serifStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFDF6EC),
                  letterSpacing: 2)),
        ),
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
