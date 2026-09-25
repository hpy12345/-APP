import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/bill_repository.dart';
import '../theme/palette.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../viewmodel/ledger_view_model.dart';
import '../widgets/bar_rank.dart';
import '../widgets/donut_chart.dart';
import '../widgets/paper.dart';
import '../widgets/year_bars.dart';
import 'data_page.dart';

/// 统计页（复刻模拟版 page-stat）：
/// 月 / 年粒度切换 + 时间步进器 → 本期收支双卡 → 环形图（月）/ 12 月双柱（年）
/// → 分类排行。右上角入口进入「数据管理」（备份 / 恢复 / 关于）。
class StatPage extends StatefulWidget {
  const StatPage({super.key});

  @override
  State<StatPage> createState() => _StatPageState();
}

class _StatPageState extends State<StatPage> {
  String _grain = 'month'; // 'month' | 'year'
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    // 口径对齐首页：默认落在「最新一笔账单所在月」而非系统当前月。
    // 否则用户忘了记账、跨月后打开统计页会看到一张空环形图，
    // 而首页明明展示着上月结余。
    final mk = context.read<LedgerViewModel>().activeMonth;
    _year = int.parse(mk.substring(0, 4));
    _month = int.parse(mk.substring(5, 7));
  }

  String get _curKey => '$_year-${_month.toString().padLeft(2, '0')}';

  /// 数据范围收窄后（例如把最早那批账单删掉）把游标夹回区间内，
  /// 否则步进按钮会「点了没反应」，用户卡在已无数据的空档月份。
  /// 注意：这里直接改字段而不 setState —— 本方法在 build 期间调用，
  /// 赋值只影响同一次 build 的后续计算，属于幂等的自我修正。
  void _clampToRange(DataRange rng) {
    if (_curKey.compareTo(rng.minMonth) < 0) {
      _year = int.parse(rng.minMonth.substring(0, 4));
      _month = int.parse(rng.minMonth.substring(5, 7));
    } else if (_curKey.compareTo(rng.maxMonth) > 0) {
      _year = int.parse(rng.maxMonth.substring(0, 4));
      _month = int.parse(rng.maxMonth.substring(5, 7));
    }
  }

  void _shift(int delta) {
    final rng = context.read<LedgerViewModel>().dataRange;
    setState(() {
      if (_grain == 'year') {
        final ny = _year + delta;
        if (ny < int.parse(rng.minMonth.substring(0, 4)) ||
            ny > int.parse(rng.maxMonth.substring(0, 4))) return;
        _year = ny;
      } else {
        final next = monthKeyShift(_curKey, delta);
        if (next.compareTo(rng.minMonth) < 0 ||
            next.compareTo(rng.maxMonth) > 0) return;
        _year = int.parse(next.substring(0, 4));
        _month = int.parse(next.substring(5, 7));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();
    final rng = vm.dataRange;
    _clampToRange(rng);
    final isYear = _grain == 'year';

    // ── 本期数据 ──
    final rows = isYear
        ? vm.expenseByCategoryOfYear(_year)
        : vm.expenseByCategoryOfMonth(_curKey);
    final totalExpense = rows.fold<int>(0, (s, r) => s + r.cents);
    final income = isYear
        ? vm.monthlySumsOfYear(_year)
            .fold<int>(0, (s, m) => s + m.income)
        : vm.monthSum(_curKey).income;
    final colors = Palette.chartColors;

    // 步进边界
    final canPrev = isYear
        ? _year > int.parse(rng.minMonth.substring(0, 4))
        : _curKey.compareTo(rng.minMonth) > 0;
    final canNext = isYear
        ? _year < int.parse(rng.maxMonth.substring(0, 4))
        : _curKey.compareTo(rng.maxMonth) < 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 头部 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('统计',
                                style: serifStyle.copyWith(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3)),
                            const SizedBox(height: 4),
                            Text(
                              isYear
                                  ? '$_year 年 · 全年收支概览'
                                  : '$_year 年 $_month 月 · 支出构成',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Palette.textSub,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      // 数据管理入口（备份 / 恢复 / 关于）
                      IconButton(
                        tooltip: '数据管理',
                        icon: const Icon(Icons.inventory_2_outlined,
                            color: Palette.textSub, size: 22),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const DataPage()),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 粒度切换 + 时间步进 ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // 月 / 年 段控
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECE2D0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Palette.line),
                        ),
                        child: Row(
                          children: [
                            _grainBtn('月', 'month'),
                            _grainBtn('年', 'year'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 步进器
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          decoration: BoxDecoration(
                            color: Palette.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Palette.line),
                          ),
                          child: Row(
                            children: [
                              _stepBtn('‹', canPrev, () => _shift(-1)),
                              Expanded(
                                child: Text(
                                  isYear
                                      ? '$_year 年'
                                      : '$_year 年 $_month 月',
                                  textAlign: TextAlign.center,
                                  style: serifStyle.copyWith(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                      color: Palette.brand),
                                ),
                              ),
                              _stepBtn('›', canNext, () => _shift(1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 本期支出 / 收入双卡 ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniCard(
                          title: isYear ? '全年支出' : '本月支出',
                          value: '¥${fmtCents(totalExpense)}',
                          valueColor: Palette.expense,
                          barGradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFC9503F), Color(0xFF8D3227)]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniCard(
                          title: isYear ? '全年收入' : '本月收入',
                          value: '¥${fmtCents(income)}',
                          valueColor: Palette.income,
                          barGradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF6D9D76), Color(0xFF3F6A4C)]),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 月：环形图 ／ 年：12 月双柱 ──
                if (!isYear)
                  PanelCard(
                    title: '支出分类占比',
                    trailing: rows.length > 6
                        ? '前 6 · 共 ${rows.length} 类'
                        : '共 ${rows.length} 类',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DonutChart(
                            rows: rows,
                            colors: colors,
                            totalCents: totalExpense),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DonutLegend(
                              rows: rows,
                              colors: colors,
                              categoryMap: vm.categoryMap,
                              totalCents: totalExpense),
                        ),
                      ],
                    ),
                  )
                else
                  PanelCard(
                    title: '12 个月收支走势',
                    trailing: _yearTip(vm),
                    child: Column(
                      children: [
                        YearBars(
                            months: vm.monthlySumsOfYear(_year),
                            year: _year),
                        const YearLegend(),
                      ],
                    ),
                  ),

                // ── 分类排行 ──
                PanelCard(
                  title: isYear ? '全年分类排行' : '分类排行',
                  trailing: '按金额降序',
                  child: BarRank(
                      rows: rows,
                      colors: colors,
                      categoryMap: vm.categoryMap,
                      totalCents: totalExpense),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _yearTip(LedgerViewModel vm) {
    final months = vm.monthlySumsOfYear(_year);
    var max = 0;
    for (final m in months) {
      if (m.expense > max) max = m.expense;
      if (m.income > max) max = m.income;
    }
    return '峰值 ¥${fmtCentsShort(max)}';
  }

  Widget _grainBtn(String label, String grain) {
    final on = _grain == grain;
    return GestureDetector(
      onTap: () => setState(() => _grain = grain),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: on ? Palette.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: on ? Border.all(color: const Color(0x4DB08D4F)) : null,
        ),
        child: Text(label,
            style: serifStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? Palette.brand : Palette.textSub)),
      ),
    );
  }

  Widget _stepBtn(String arrow, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Text(arrow,
            style: serifStyle.copyWith(
                fontSize: 15,
                color: enabled
                    ? Palette.textSub
                    : Palette.textSub.withAlpha(77))),
      ),
    );
  }
}

/// 收支小卡（左竖条色标 + 宋体数值）
class _MiniCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;
  final LinearGradient barGradient;

  const _MiniCard({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.barGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: paperCard(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: barGradient,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: serifStyle.copyWith(
                        fontSize: 12,
                        color: Palette.textSub,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: serifStyle.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
