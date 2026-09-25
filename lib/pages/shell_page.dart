import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/palette.dart';
import '../viewmodel/ledger_view_model.dart';
import 'add_page.dart';
import 'home_page.dart';
import 'stat_page.dart';

/// 应用主壳：三页 IndexedStack + 国风底部标签栏 + 印章式「记一笔」FAB。
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  bool _onboardingShown = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();

    // ① 初始化失败：给出可读原因 + 重试，而不是无限加载圈
    if (vm.initError != null) {
      return Scaffold(
        backgroundColor: Palette.screenBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📕', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 14),
                  Text('数据初始化失败',
                      style: serifStyle.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text(
                    vm.initError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: Palette.textSub, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: vm.retryInit,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF9A3E32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    child: Text('重试',
                        style: serifStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Palette.goldSoft)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ② 初始化中
    if (!vm.ready) {
      return const Scaffold(
        backgroundColor: Palette.screenBg,
        body: Center(
          child: CircularProgressIndicator(color: Palette.brand),
        ),
      );
    }

    // 首启引导（落地方案 P0：不默认注入示例数据，改为用户选择）
    if (vm.needsOnboarding && !_onboardingShown) {
      _onboardingShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding(vm));
    }

    // 返回键语义：不在首页时先回首页，而不是直接退出 App
    return PopScope(
      canPop: vm.currentTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) vm.switchTab(0);
      },
      child: Scaffold(
        // 必须是不透明底色：Flutter 的 Surface 本身不透明，凡是 App 没画到的
        // 区域在真机上会露出黑色（表现为底部一条黑带 / 中间缺口周围发黑）。
        // 这里兜一层宣纸色，任何缝隙都只会是同色，不会发黑。
        backgroundColor: Palette.screenBg,
        // 自绘键盘自带高度，禁止系统键盘再上推整页（否则底部会挤出缝隙）
        resizeToAvoidBottomInset: false,
        // 注意：不开 extendBody —— 记账页自绘键盘需要贴在标签栏「上方」
        //（与模拟版布局一致：pages 区结束 → tabbar → 安全区）
        body: IndexedStack(
          index: vm.currentTab,
          children: const [HomePage(), AddPage(), StatPage()],
        ),
        // 不再用 floatingActionButton：「记一笔」入口改成标签栏中间的第 3 格
        // （见 _TabBar 的 _AddSlot）。两条理由：
        // ① 悬浮球是跨在「内容区 / 标签栏」交界上的，必然压住记账页底部
        //    —— 换系统键盘前它正压在「0 / 今天」键上；
        // ② 中间格完全落在标签栏内，点击热区不会被父级裁剪，也不用再靠
        //    CircularNotchedRectangle 挖缺口。
        bottomNavigationBar: _TabBar(
          currentIndex: vm.currentTab,
          onTap: vm.switchTab,
        ),
      ),
    );
  }

  void _showOnboarding(LedgerViewModel vm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Palette.gold),
        ),
        title: Text('欢迎使用记账本',
            style: serifStyle.copyWith(
                fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 2)),
        content: const Text(
          '数据全部保存在本机，不联网、零权限。\n\n'
          '可以先写入一组演示数据体验，也可以直接从空账本开始。',
          style: TextStyle(fontSize: 13, color: Palette.textSub, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              vm.finishOnboarding();
              Navigator.of(ctx).pop();
            },
            child: const Text('直接开始',
                style: TextStyle(color: Palette.textSub)),
          ),
          TextButton(
            onPressed: () {
              vm.loadDemoData();
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF9A3E32),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
            child: Text('写入演示数据',
                style: serifStyle.copyWith(
                    color: Palette.goldSoft, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// 标签栏里的「记一笔」格：朱砂印章，居中于账单 / 统计之间。
///
/// 居中不是靠魔数，而是布局本身保证的：左右两个 Tab 都是 Expanded，
/// 中间这一格是固定宽 —— 剩余空间被两侧等分，中间格必然落在屏幕水平中线上。
class _AddSlot extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  /// 与两侧 Tab 的间距（也是印章的呼吸区）
  static const double slotWidth = 76;

  const _AddSlot({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: slotWidth,
      // 整格可点（热区比印章大一圈），空手点也不会落空
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.5),
                radius: 0.9,
                colors: [
                  Color(0xFFB8544A),
                  Color(0xFF9E4034),
                  Color(0xFF7F2F26)
                ],
                stops: [0.0, 0.58, 1.0],
              ),
              border: Border.all(
                  color: active
                      ? const Color(0xE6B08D4F)
                      : const Color(0x8CB08D4F),
                  width: active ? 1.6 : 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x668D3227),
                    offset: Offset(0, 4),
                    blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.add, color: Color(0xFFEFE2C8), size: 24),
          ),
        ),
      ),
    );
  }
}

/// 国风底部标签栏：宣纸半透 + 账单 / 记一笔 / 统计 三格
class _TabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TabBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      // 不透明：原来的 0xEB 半透会让材质与背后的黑色混合发灰
      color: const Color(0xFFF7F1E6),
      elevation: 0,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          _tab(0, Icons.home_outlined, '账单'),
          _AddSlot(active: currentIndex == 1, onTap: () => onTap(1)),
          _tab(2, Icons.pie_chart_outline, '统计'),
        ],
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) {
    final on = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 23, color: on ? Palette.brand : const Color(0xFFA89A86)),
            const SizedBox(height: 3),
            Text(label,
                style: serifStyle.copyWith(
                  fontSize: 11.5,
                  letterSpacing: 1.4,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? Palette.brand : const Color(0xFFA89A86),
                )),
          ],
        ),
      ),
    );
  }
}
