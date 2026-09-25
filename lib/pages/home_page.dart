import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/bill_repository.dart';
import '../models/bill.dart';
import '../theme/palette.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../viewmodel/ledger_view_model.dart';
import '../widgets/bill_tile.dart';
import '../widgets/budget_bar.dart';
import '../widgets/calendar_dialog.dart';
import '../widgets/fit_text.dart';
import '../widgets/modal_input.dart';
import '../widgets/paper.dart';
import '../widgets/toast.dart';

/// 首页 · 账单页
///
/// 复刻模拟版：净资产卡（现金/债务拆解）→ 当月结余卡（预算 5 级预警）
/// → 流水账（日/月双粒度 + 日历精确定位 + 滑删撤销）。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WealthCard(wealth: vm.wealth),
                const SizedBox(height: 12),
                _HeroCard(vm: vm),
                const SizedBox(height: 18),
                _DayBar(vm: vm),
                const SizedBox(height: 9),
                _BillArea(vm: vm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ 净资产卡 ═════════════════════════════════════════════

class _WealthCard extends StatelessWidget {
  final Wealth? wealth;
  const _WealthCard({required this.wealth});

  @override
  Widget build(BuildContext context) {
    final w = wealth ?? const Wealth(cash: 0, receivable: 0, payable: 0);
    final net = w.netAsset;
    final neg = net < 0;

    return Container(
      decoration: paperCard(),
      child: Stack(
        children: [
          // 左侧竖条：盈余青绿 / 赤字朱砂
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: neg
                        ? const [Color(0xFFC9564A), Palette.expense]
                        : const [Color(0xFF5F9273), Palette.income],
                  ),
                ),
              ),
            ),
          ),
          // 右下金晕
          Positioned(
            right: -34,
            bottom: -42,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    neg
                        ? const Color(0x24B23A30)
                        : const Color(0x21B08D4F),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.68],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行：朱砂小方点 + 净资产
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(right: 7),
                      color: const Color(0xC09E4034),
                    ),
                    Text('净资产',
                        style: serifStyle.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                            color: Palette.textSub)),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    // 左：净资产大数字
                    Expanded(
                      child: FitText(
                        text:
                            '${net < 0 ? '-' : ''}¥${fmtCents(net)}',
                        maxFontSize: 44,
                        minFontSize: 26,
                        style: serifStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          height: 1.12,
                          color: neg ? Palette.expense : Palette.income,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 右：拆解「现金 / 债务」
                    Container(
                      padding: const EdgeInsets.only(left: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                            left: BorderSide(color: Color(0x4DB08D4F))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _decomposeRow(
                            '现金',
                            fmtCentsShort(w.cash),
                            w.cash < 0 ? Palette.expense : Palette.income,
                            w.cash < 0,
                          ),
                          const SizedBox(height: 6),
                          Tooltip(
                            message: w.receivable == 0 && w.payable == 0
                                ? '无借贷往来'
                                : '我欠别人 ¥${fmtCents(w.payable)}\n'
                                    '别人欠我 ¥${fmtCents(w.receivable)}',
                            child: _decomposeRow(
                              '债务',
                              fmtCentsShort(w.netDebt),
                              w.receivable == 0 && w.payable == 0
                                  ? Palette.textSub
                                  : w.netDebt < 0
                                      ? Palette.expense
                                      : Palette.income,
                              w.netDebt < 0,
                              mute: w.receivable == 0 && w.payable == 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _decomposeRow(String label, String value, Color color, bool neg,
      {bool mute = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$label ',
            style: serifStyle.copyWith(
                fontSize: 11.5,
                letterSpacing: 1.2,
                color: Palette.textSub.withAlpha(mute ? 128 : 255))),
        Text('${neg ? '-' : ''}¥$value',
            style: serifStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: mute ? Palette.textSub.withAlpha(128) : color)),
      ],
    );
  }
}

// ═══ 当月结余 + 预算卡 ═════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final LedgerViewModel vm;
  const _HeroCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final mk = vm.activeMonth;
    final list = vm.billsOfMonth(mk);
    final m = vm.monthSum(mk);
    final budget = vm.budgetOf(mk);
    final pct = budget > 0 ? m.expense / budget * 100 : 0.0;
    final left = budget - m.expense;

    return Container(
      decoration: paperCard(),
      child: Stack(
        children: [
          // 金左条
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 4,
                decoration: const BoxDecoration(
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(8)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Palette.gold, Color(0xFFD8BD8A)],
                  ),
                ),
              ),
            ),
          ),
          // 右下金晕
          Positioned(
            right: -34,
            bottom: -42,
            child: Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1FB08D4F), Colors.transparent],
                  stops: [0.0, 0.68],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 首行：月份 · 当月结余标签 · 笔数
                Row(
                  children: [
                    Text(monthKeyCn(mk),
                        style: serifStyle.copyWith(
                            fontSize: 13.5, letterSpacing: 2)),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.only(left: 9),
                      decoration: const BoxDecoration(
                          border: Border(
                              left: BorderSide(color: Color(0x57B08D4F)))),
                      child: Text('当月结余 (元)',
                          style: serifStyle.copyWith(
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.textSub)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Palette.goldSoft,
                        border:
                            Border.all(color: const Color(0x6BB08D4F)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('${list.length} 笔',
                          style: serifStyle.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Palette.gold,
                              letterSpacing: 1.2)),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // 结余大数字
                FitText(
                  text:
                      '${m.balance < 0 ? '-' : ''}¥${fmtCents(m.balance)}',
                  maxFontSize: 34,
                  minFontSize: 22,
                  style: serifStyle.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1.08,
                    color: m.balance < 0 ? Palette.expense : Palette.income,
                  ),
                ),
                const SizedBox(height: 4),
                // 收 / 支明细
                Row(
                  children: [
                    Text('收 ¥${fmtCents(m.income)}',
                        style: serifStyle.copyWith(
                            fontSize: 12,
                            color: Palette.income,
                            letterSpacing: 1)),
                    const SizedBox(width: 8),
                    Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x808D8273))),
                    const SizedBox(width: 8),
                    Text('支 ¥${fmtCents(m.expense)}',
                        style: serifStyle.copyWith(
                            fontSize: 12,
                            color: Palette.expense,
                            letterSpacing: 1)),
                  ],
                ),
                // 预算行
                const SizedBox(height: 14),
                const Divider(height: 1, color: Palette.line),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当月预算支出',
                            style: serifStyle.copyWith(
                                fontSize: 12,
                                color: Palette.textSub,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 3),
                        Text(
                          _budgetCaption(budget, left, pct),
                          style: serifStyle.copyWith(
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                            fontWeight: budget > 0 && left < 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: budget <= 0
                                ? Palette.textSub.withAlpha(184)
                                : left < 0
                                    ? Palette.expense
                                    : pct >= 80
                                        ? const Color(0xFFA8762A)
                                        : Palette.textSub.withAlpha(184),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 预算数字（可点击编辑）
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _editBudget(context, mk, budget),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Color(0x80B08D4F),
                                  width: 1,
                                  style: BorderStyle.solid)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('¥',
                                style: serifStyle.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Palette.text.withAlpha(179))),
                            Text(budget > 0 ? fmtCents(budget) : '0',
                                style: serifStyle.copyWith(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                BudgetBar(pct: pct),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _budgetCaption(int budget, int left, double pct) {
    if (budget <= 0) return '尚未设定 · 点击右侧数字设定';
    if (left >= 0) {
      return '余 ¥${fmtCents(left)} · 已用 ${pct.toStringAsFixed(0)}%';
    }
    return '超支 ¥${fmtCents(-left)} · ${pct.toStringAsFixed(0)}%';
  }

  Future<void> _editBudget(
      BuildContext context, String monthKey, int budget) async {
    final cents = await showAmountInputDialog(
      context,
      title: '设置 ${monthKeyCn(monthKey)} 预算',
      tip: '预算用于对比当月支出，留空或填 0 表示不设预算',
      initial: budget > 0 ? centsToBuffer(budget) : '',
    );
    if (cents == null) return;
    vm.setBudget(monthKey, cents);
    if (context.mounted) {
      showAppToast(context, cents <= 0 ? '已取消预算' : '预算已保存');
    }
  }
}

// ═══ 流水账：日 / 月切换栏 ═════════════════════════════════

class _DayBar extends StatelessWidget {
  final LedgerViewModel vm;
  const _DayBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final v = vm.billView;
    final rng = vm.dataRange;
    final monthMode = v.mode == 'month';
    final isCurrent = monthMode
        ? v.month == todayMonthKey()
        : v.date == todayInt();

    final canPrev =
        monthMode ? v.month != rng.minMonth : v.date != rng.minDate;
    final canNext = monthMode
        ? v.month != todayMonthKey()
        : v.date != todayInt();

    return Row(
      children: [
        _navBtn('‹', canPrev, () => vm.shiftView(-1)),
        const SizedBox(width: 7),
        // 中间：当前日期/月份（点开日历）
        Expanded(
          child: _CardButton(
            height: 40,
            onTap: () => showLedgerCalendar(
              context,
              monthGrain: monthMode,
              // 月粒度下必须用 v.month 而非 v.date：翻月只改 month，
              // 沿用 v.date 会让日历永远停在「切到月粒度那一刻」的月份。
              initYear: monthMode
                  ? int.parse(v.month.substring(0, 4))
                  : dtOf(v.date).year,
              initMonth: monthMode
                  ? int.parse(v.month.substring(5, 7))
                  : dtOf(v.date).month,
              selectedDate: v.date,
              selectedMonth: v.month,
              bills: vm.bills,
              onPickDate: vm.selectDate,
              onPickMonth: vm.selectMonth,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    monthMode
                        ? monthKeyCn(v.month)
                        : '${fmtDateCn(v.date)} ${weekLabel(v.date)}',
                    overflow: TextOverflow.ellipsis,
                    style: serifStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Palette.goldSoft,
                      border:
                          Border.all(color: const Color(0x6BB08D4F)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(monthMode ? '当月' : '当天',
                        style: serifStyle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Palette.gold)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 7),
        _navBtn('›', canNext, () => vm.shiftView(1)),
        const SizedBox(width: 7),
        // 日 / 月 段控
        _CardButton(
          height: 40,
          onTap: () => vm.switchGrain(monthMode ? 'day' : 'month'),
          child: Row(
            children: [
              _grainCell('日', !monthMode, () => vm.switchGrain('day')),
              Container(width: 1, height: 24, color: Palette.line),
              _grainCell('月', monthMode, () => vm.switchGrain('month')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grainCell(String label, bool on, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 30,
        alignment: Alignment.center,
        color: on ? Palette.goldSoft : Colors.transparent,
        child: Text(label,
            style: serifStyle.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: on ? Palette.gold : Palette.textSub)),
      ),
    );
  }

  Widget _navBtn(String arrow, bool enabled, VoidCallback onTap) {
    return _CardButton(
      width: 34,
      height: 40,
      onTap: enabled ? onTap : null,
      child: Text(arrow,
          style: serifStyle.copyWith(
              fontSize: 17,
              color: enabled
                  ? Palette.textSub
                  : Palette.textSub.withAlpha(82))),
    );
  }
}

class _CardButton extends StatelessWidget {
  final double? width;
  final double height;
  final VoidCallback? onTap;
  final Widget child;

  const _CardButton(
      {this.width, required this.height, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Palette.line),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x2E78603C), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

// ═══ 账单区 ══════════════════════════════════════════════

class _BillArea extends StatelessWidget {
  final LedgerViewModel vm;
  const _BillArea({required this.vm});

  @override
  Widget build(BuildContext context) {
    final v = vm.billView;
    final items = vm.billsOfView();

    if (items.isEmpty) {
      final monthMode = v.mode == 'month';
      return Column(
        children: [
          const SizedBox(height: 30),
          const Text('🗒️', style: TextStyle(fontSize: 38)),
          const SizedBox(height: 12),
          Text(
            monthMode
                ? '本月还没有账单\n点击下方「+」记一笔'
                : '${v.date == todayInt() ? '今天' : fmtDateCn(v.date)}还没有账单\n点击下方「+」记一笔',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Palette.textSub, height: 1.9),
          ),
          const SizedBox(height: 30),
        ],
      );
    }

    // 小计
    final sum = sumUp(items);
    final strip = DaySumStrip(sum: sum, count: items.length);

    // 月模式：按日期分组；日模式：平铺
    if (v.mode == 'month') {
      final groups = <int, List<Bill>>{};
      for (final b in items) {
        groups.putIfAbsent(b.date, () => []).add(b);
      }
      final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          strip,
          for (final d in dates) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d == todayInt()
                          ? '今天'
                          : '${fmtDateCn(d)} ${dateLabel(d)}',
                      style: serifStyle.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8),
                    ),
                  ),
                  Text(
                    _groupSummary(groups[d]!),
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: Palette.textSub,
                        letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            BillListCard(children: [
              for (var i = 0; i < groups[d]!.length; i++)
                BillTile(
                  bill: groups[d]![i],
                  category: vm.categoryMap[groups[d]![i].categoryId],
                  showDivider: i > 0,
                  onDelete: (bill) => _delete(context, bill),
                ),
            ]),
            const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        strip,
        BillListCard(children: [
          for (var i = 0; i < items.length; i++)
            BillTile(
              bill: items[i],
              category: vm.categoryMap[items[i].categoryId],
              showDivider: i > 0,
              onDelete: (bill) => _delete(context, bill),
            ),
        ]),
      ],
    );
  }

  String _groupSummary(List<Bill> list) {
    final s = sumUp(list);
    final inc = s.income > 0 ? '收 ¥${fmtCents(s.income)} · ' : '';
    return '$inc支 ¥${fmtCents(s.expense)}';
  }

  void _delete(BuildContext context, Bill bill) {
    vm.deleteBill(bill);
    showUndoToast(context, '已删除', () => vm.undoDelete(bill));
  }
}
