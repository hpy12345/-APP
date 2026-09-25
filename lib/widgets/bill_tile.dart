import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bill_repository.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../theme/palette.dart';
import '../utils/money.dart';

/// 账单行（复刻模拟版 .bill）。
///
/// 删除交互：**左滑露出「删除」按钮 → 再点一下才真的删**。
/// 之前用 `Dismissible`，划到底立刻删除，误触即丢数据（删除虽可撤销，
/// 但用户明确要求「再点一下」）。
///
/// 手势细节：
/// - 拖动跟手，松手按「位移 > 1/3 宽度」或「甩动速度」吸附到展开 / 收起
/// - 展开后点行内容 = 收起（不误删）；点右侧删除条 = 执行删除
/// - 删除仍走调用方给的软删 + 撤销 Toast 通道
class BillTile extends StatefulWidget {
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
  State<BillTile> createState() => _BillTileState();
}

class _BillTileState extends State<BillTile>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 78;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _offset = Tween<double>(
    begin: 0,
    end: -_actionWidth,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  double _dragBase = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _opened => _ctrl.value > 0.5;

  void _onDragStart(DragStartDetails _) => _dragBase = _offset.value;

  void _onDragUpdate(DragUpdateDetails d) {
    final v = (_dragBase + (d.primaryDelta ?? 0)).clamp(-_actionWidth, 0.0);
    _ctrl.value = -v / _actionWidth; // 0 → 收起，1 → 完全展开
  }

  void _onDragEnd(DragEndDetails d) {
    final vx = d.velocity.pixelsPerSecond.dx;
    if (vx < -320) {
      _ctrl.forward();
    } else if (vx > 320) {
      _ctrl.reverse();
    } else if (-_offset.value > _actionWidth / 3) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _close() {
    HapticFeedback.selectionClick();
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showDivider)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 66),
              height: 1,
              color: const Color(0x33E6DCC9),
            ),
          ),
        Stack(
          children: [
            // 右侧删除条（被行内容盖住，左滑后才露出来）
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _actionWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onDelete(widget.bill);
                },
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFB23A30), Color(0xFF8F2C24)]),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          color: Color(0xFFFDF6EC), size: 22),
                      SizedBox(height: 2),
                      Text('删除',
                          style: TextStyle(
                              color: Color(0xFFFDF6EC),
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _offset,
              builder: (context, child) => Transform.translate(
                offset: Offset(_offset.value, 0),
                child: child,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                // 注意：这里不能写成 `_opened ? _close : null` —— 该 widget 是
                // AnimatedBuilder 的缓存 child，动画过程中不会重建，条件会在
                // 构建时被冻结成 null。改为在回调里实时判断。
                onTap: () {
                  if (_opened) _close();
                },
                child: _BillRow(bill: widget.bill, category: widget.category),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 行内容（图标 / 名称 / 备注 / 金额）
class _BillRow extends StatelessWidget {
  final Bill bill;
  final LedgerCategory? category;

  const _BillRow({required this.bill, required this.category});

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

    return Container(
      color: Palette.card,
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
