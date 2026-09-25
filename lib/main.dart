import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/shell_page.dart';
import 'theme/palette.dart';
import 'viewmodel/ledger_view_model.dart';

/// 记账本 · 国风 Android 版
///
/// 架构（落地方案 3.2 四层单向数据流）：
/// ```
/// UI 层（pages / widgets）        只渲染状态 · 上报事件
///   ↓ 事件                 ↑ 状态
/// 状态层（LedgerViewModel）        业务规则 + 表单/视图游标
///   ↓ 接口调用
/// 数据层（BillRepository 实现）    SQL 聚合下推 · 事务化导入 · SAF 备份
///   ↓
/// SQLite v4（bill/category/account/budget）+ 自动备份快照
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全面屏 edge-to-edge：状态栏 / 导航栏透明 + 深色图标（宣纸底色）
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 应用启动前完成数据初始化（开库 → 迁移检查 → 种子 → 全量加载）。
  // init() 内部已 try/catch：失败时置 vm.initError，由 ShellPage 展示
  // 「初始化失败 + 原因 + 重试」错误态，不会闪退也不会永远转圈。
  final vm = LedgerViewModel();
  await vm.init();

  runApp(
    ChangeNotifierProvider.value(value: vm, child: const LedgerApp()),
  );
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账本',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 全局朱砂主色（原生组件如日期选择器、对话框随之取色）
        colorScheme:
            ColorScheme.fromSeed(seedColor: Palette.brand).copyWith(
          primary: Palette.brand,
          secondary: Palette.gold,
          surface: Palette.paper,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      locale: const Locale('zh', 'CN'),
      home: const ShellPage(),
    );
  }
}
