import 'package:flutter/material.dart';

/// 预算用量分级（直译模拟版 usageLevel）：
/// ''     < 80%   常态（描金）
/// warn   ≥ 80%   接近超支（暖金转赭石）
/// over   ≥ 100%  已超支（朱砂）
/// over2  ≥ 150%  严重超支（深朱砂）
/// over3  ≥ 250%  极端超支（浓墨赤 + 脉动）
String usageLevel(double pct) {
  if (pct >= 250) return 'over3';
  if (pct >= 150) return 'over2';
  if (pct >= 100) return 'over';
  if (pct >= 80) return 'warn';
  return '';
}

/// 预算进度条（5 级预警色 + >250% 脉动辉光）。
/// 宽度按真实比例填充，超 100% 封顶满格。
class BudgetBar extends StatelessWidget {
  final double pct; // 真实百分比（可 > 100）

  const BudgetBar({super.key, required this.pct});

  @override
  Widget build(BuildContext context) {
    final level = usageLevel(pct);
    final fill = switch (level) {
      'warn' => const LinearGradient(colors: [Color(0xFFD9A441), Color(0xFFC07A3E)]),
      'over' => const LinearGradient(colors: [Color(0xFFD06A4A), Color(0xFFB23A30)]),
      'over2' => const LinearGradient(colors: [Color(0xFFB23A30), Color(0xFF8D3227)]),
      'over3' => const LinearGradient(colors: [Color(0xFF8D3227), Color(0xFF5E1F18)]),
      _ => const LinearGradient(colors: [Color(0xFFC9AB6E), Color(0xFFB08D4F)]),
    };

    return Container(
      height: 6,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEBE1CD),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct.clamp(0, 100).toDouble() / 100),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            final bar = FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: fill),
              ),
            );
            // >250%：脉动辉光
            if (level == 'over3') return _Pulse(child: bar);
            return bar;
          },
        ),
      ),
    );
  }
}

/// 脉动辉光（复刻模拟版 barPulse 1.6s 循环）
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final alpha = (0.38 + 0.30 * t); // 模拟版：rgba(141,50,39,.38) ↔ .68
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8D3227)
                    .withAlpha((alpha * 255).round()),
                blurRadius: 6 + 6 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
