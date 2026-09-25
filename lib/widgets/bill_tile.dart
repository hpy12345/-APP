import 'package:flutter/material.dart';

import '../data/bill_repository.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 账单行（复刻模拟版 .bill）+ 右滑删除（Android 习惯交互，替代模拟版点行展开）。
/// 删除走软删 + 撤销 Toast，误删可恢复（落地方案 P0 #2）。
class BillTile extends StatelessWidget {
  final Bill bill;
  final LedgerCategory? category;
  final bool showDivider; // 组内非首行显示左侧缩进分割线
  final ValueChanged<Bill> onDelete;

  const BillTile({
    super.key,
    required this.bill,
    required this.category,
    this.showDivider = false,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = category ??
        const LedgerCategory(
            id: 'other', name: '其他', icon: '📦', bg: 0xFFEAE5DC, type: 'expense');

    // 符号与颜色按「金额对净现金流的实际方向」（直译模拟版：
    // 支出负数（冲销）显示为 + 绿；收入负数显示为 - 红）
    final cashIn = bill.cashIn;
    final color = cashIn ? Palette.income : Palette.expense;
    final sign = cashIn ? '+' : '-';

    final isDebt = Palette.debtCategories.contains(bill.categoryId);

    return Dismissible(
      key: ValueKey('bill-${bill.id}-${bill.uuid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB23A30), Color(0xFF8F2C24)]),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFFDF6EC), size: 20),
            Text('删除',
                style: TextStyle(
                    color: Color(0xFFFDF6EC),
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) {
        onDelete(bill);
      },
      child: Container(
        color: Palette.card,
        child: Column(
          children: [
            if (showDivider)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(left: 66),
                  height: 1,
                  color: const Color(0x33E6DCC9),
                ),
              ),
            InkWell(
              onTap: () {}, // 保留点行交互占位（编辑功能为 P0 扩展点，见 README）
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    // 分类图标：方形朱印感
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cat.bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x29967E5C)),
                      ),
                      alignment: Alignment.center,
                      child: Text(cat.icon, style: const TextStyle(fontSize: 19)),
                    ),
                    const SizedBox(width: 13),
                    // 名称 + 备注
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(cat.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: serifStyle.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2)),
                              ),
                              if (isDebt) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3F8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('往来',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Palette.textSub,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            bill.note.isEmpty ? '无备注' : bill.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Palette.textSub,
                                letterSpacing: 0.2),
                          ),
                        ],
                      ),
                    ),
                    // 金额
                    Text('$sign¥${fmtCents(bill.amount)}',
                        style: serifStyle.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: -0.2,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账单组容器：宣纸卡圆角 + 裁切
class BillListCard extends StatelessWidget {
  final List<Widget> children;
  const BillListCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: paperCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// 当日/当月小计行（直译模拟版 .day-sum）
class DaySumStrip extends StatelessWidget {
  final MonthSum sum;
  final int count;

  const DaySumStrip({super.key, required this.sum, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 11),
      child: Row(
        children: [
          _item('支出', '¥${fmtCents(sum.expense)}', Palette.expense),
          const SizedBox(width: 15),
          _item('收入', '¥${fmtCents(sum.income)}', Palette.income),
          const Spacer(),
          Text('共 $count 笔',
              style: const TextStyle(
                  fontSize: 12,
                  color: Palette.textSub,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _item(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Palette.textSub)),
        const SizedBox(width: 4),
        Text(value,
            style: serifStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}
