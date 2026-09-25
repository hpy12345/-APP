import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_db.dart';
import '../data/backup_service.dart';
import '../data/bill_repository.dart';
import '../models/backup.dart';
import '../models/bill.dart';
import '../models/category.dart';
import '../utils/dates.dart';
import '../utils/money.dart';

/// 记账表单状态（键盘缓冲逻辑直译模拟版：2 位小数 / 9 位整数 / 前导 0 替换）
class AddFormState {
  String type = 'expense'; // 'expense' | 'income'
  String categoryId = 'food';
  String buffer = ''; // 金额输入缓冲（元），如 '38.5'
  String note = '';
  int dateInt = todayInt();

  bool get hasValue => buffer.isNotEmpty && buffer != '0';
}

/// 首页流水视图（直译模拟版 state.billView）
class BillViewState {
  String mode = 'day'; // 'day' | 'month'
  int date = todayInt();
  String month = todayMonthKey();
}

enum SaveResult { ok, needAmount, needCategory }

/// 全局唯一 ViewModel。
///
/// 分层约定（落地方案 3.2 单向数据流）：
/// UI 层只读 VM 状态 + 调 VM 方法，不做业务计算；业务规则全部收敛在这里与数据层。
/// 后续页面状态膨胀时，可按方案拆为「每页一个 Notifier」（Riverpod 迁移映射见 README）。
class LedgerViewModel extends ChangeNotifier {
  LedgerViewModel({BillRepository? repo, BackupService? backup})
      : repo = repo ?? SqfliteBillRepository() {
    this.backup = backup ?? BackupService(this.repo);
  }

  final BillRepository repo;
  late final BackupService backup;

  // ── 数据态 ──────────────────────────────────────────────
  List<Bill> bills = []; // 未删除，date DESC
  Map<String, int> budgets = {}; // 'yyyy-MM' → cents
  List<LedgerCategory> categories = [];
  Map<String, LedgerCategory> categoryMap = {};
  Wealth? wealth; // SQL 聚合缓存（首页净资产卡）

  // ── UI 态 ───────────────────────────────────────────────
  final AddFormState form = AddFormState();
  final BillViewState billView = BillViewState();
  int currentTab = 0;
  bool ready = false;
  bool needsOnboarding = false; // 首启空账本引导
  String appVersion = '';

  // ── 细粒度通知（性能） ───────────────────────────────────
  /// 记一笔表单的专用通知源。
  ///
  /// 表单每次按键（金额数字、退格、切分类）若走 [notifyListeners]，
  /// 会让同时挂在 IndexedStack 里的首页与统计页跟着整棵重建 ——
  /// 统计页还要重算环形图 / 排行 / 双柱，真机上表现为「按数字键发涩」。
  /// 表单变化只通知它，只有记账页（用 ValueListenableBuilder 订阅）会重建。
  final ValueNotifier<int> formRev = ValueNotifier<int>(0);

  /// 表单态变更：只通知 formRev（只有记账页订阅），
  /// 首页 / 统计页不会被高频按键拖着重建。
  void _bumpForm() => formRev.value++;

  /// 数据态变更（账单 / 预算 / 分类 / 视图游标）统一出口：广播全量通知。
  /// 与 [_bumpForm] 相对 —— 只有这类低频变更才值得让三页一起刷新。
  void _notifyData() => notifyListeners();

  /// 初始化失败原因（非 null 时 ShellPage 展示错误态 + 重试按钮）。
  /// 之前失败只是打日志，UI 会永久停在加载圈，用户无从判断。
  String? initError;

  Timer? _autoBackupTimer;

  /// 会话内自增序号（uuid 唯一性保证）
  int _seq = 0;

  // ═══ 启动 ═════════════════════════════════════════════

  Future<void> init() async {
    try {
      await repo.ensureSeeded();
      bills = await repo.loadBills();
      budgets = await repo.loadBudgets();
      categories = await repo.loadCategories();
      categoryMap = {for (final c in categories) c.id: c};
      _normalizeFormCategory();
      await _refreshWealth();

      final prefs = await SharedPreferences.getInstance();
      needsOnboarding =
          bills.isEmpty && !(prefs.getBool('ledger.onboarded.v1') ?? false);

      // 版本号读取失败不应阻断启动（「关于」页退化为空串）
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        appVersion = '';
      }

      initError = null;
      ready = true;
    } catch (e) {
      initError = '$e';
      ready = false;
    }
    _notifyData();
  }

  /// 初始化失败后的重试入口（ShellPage 错误态调用）
  Future<void> retryInit() async {
    initError = null;
    notifyListeners();
    await init();
  }

  /// 首启引导二选一：直接开始（记为已完成，空账本）
  Future<void> finishOnboarding() async {
    needsOnboarding = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ledger.onboarded.v1', true);
    notifyListeners();
  }

  /// 首启引导二选一：写入演示数据（模拟版 sampleBills）
  Future<void> loadDemoData() async {
    await repo.insertDemoData();
    bills = await repo.loadBills();
    await _refreshWealth();
    await finishOnboarding();
    _notifyData(); // 演示数据入库后要广播，首页/统计页才会重算
    _scheduleAutoBackup();
  }

  Future<void> _refreshWealth() async {
    wealth = await repo.wealth();
  }

  // ═══ 表单：键盘输入（直译模拟版 handleKey） ═════════════
  // 注意：本节的写入一律走 _bumpForm()，不广播全量通知 —— 见 formRev 注释。

  void setFormType(String type) {
    form.type = type;
    _normalizeFormCategory();
    _bumpForm();
  }

  void setFormCategory(String id) {
    form.categoryId = id;
    _bumpForm();
  }

  void setFormNote(String note) {
    form.note = note;
    // 备注实时入状态但不通知（无 UI 联动，避免输入卡顿）
  }

  /// 选日期（禁止未来）
  void setFormDate(int dateInt) {
    form.dateInt = dateInt;
    _bumpForm();
  }

  void clearForm() {
    form.buffer = '';
    form.note = '';
    _bumpForm();
  }

  void handleKey(String k) {
    if (k == 'back') {
      // 空缓冲直接返回：''.substring(0, -1) 会抛 RangeError 导致崩溃
      if (form.buffer.isEmpty) return;
      form.buffer = form.buffer.substring(0, form.buffer.length - 1);
    } else if (k == '.') {
      if (form.buffer.isEmpty) {
        form.buffer = '0.';
      } else if (!form.buffer.contains('.')) {
        form.buffer += '.';
      }
    } else if (k == 'today') {
      form.dateInt = todayInt();
    } else if (RegExp(r'^[0-9]$').hasMatch(k)) {
      if (form.buffer == '0') {
        form.buffer = k; // 前导 0 替换
      } else {
        final dot = form.buffer.indexOf('.');
        if (dot >= 0 && form.buffer.length - dot > 2) return; // 小数 ≤2 位
        if (form.buffer.replaceAll('.', '').length >= 9) return; // 整数 ≤9 位
        form.buffer += k;
      }
    } else {
      return;
    }
    _bumpForm();
  }

  /// 当前分类不在收支对应组时，自动切到该组第一个（直译模拟版）
  void _normalizeFormCategory() {
    if (categories.isEmpty) return; // 种子未就绪时不越界取 first
    final ok = categories.any(
        (c) => c.id == form.categoryId && c.type == form.type);
    if (!ok) {
      form.categoryId = categories
          .firstWhere((c) => c.type == form.type,
              orElse: () => categories.first)
          .id;
    }
  }

  /// 保存当前表单为账单
  SaveResult saveBill() {
    final cents = bufferToCents(form.buffer);
    if (form.buffer.isEmpty || cents <= 0) return SaveResult.needAmount;
    if (!categoryMap.containsKey(form.categoryId)) return SaveResult.needCategory;

    final now = DateTime.now().millisecondsSinceEpoch;
    final bill = Bill(
      uuid: 'b${now.toRadixString(36)}-${_seq++}', // 时间戳 + 会话内自增，保证唯一
      type: form.type,
      amount: cents,
      categoryId: form.categoryId,
      note: form.note.trim(),
      date: form.dateInt,
      createdAt: now,
      updatedAt: now,
    );

    // 乐观插入：先写内存（UI 立刻可见），再异步落库
    bills = [bill, ...bills]..sort(_byDateDesc);
    _mutate(() async {
      await repo.insertBill(bill);
      bills = await repo.loadBills();
    });

    // 重置表单（保留类型与日期，方便连续记账）+ 回首页定位该账单所在日
    form.buffer = '';
    form.note = '';
    billView.mode = 'day';
    billView.date = bill.date;
    billView.month = monthKeyOf(bill.date);
    formRev.value++;
    _notifyData();
    return SaveResult.ok;
  }

  /// 账单排序：日期倒序 → 记录时刻倒序（与 repo.loadBills 的 ORDER BY 一致）
  static int _byDateDesc(Bill a, Bill b) {
    final d = b.date.compareTo(a.date);
    return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
  }

  // ═══ 账单删除 / 撤销（软删，方案 P0「删除撤销」） ═══════

  /// 删除：**先同步从内存列表移除**再落库。
  /// 必要性：Dismissible 在 onDismissed 后要求该条目立刻离开 widget 树，
  /// 若等异步落库完成再刷新，中间任何一次 rebuild 都会触发
  /// 「A dismissed Dismissible widget is still part of the tree」断言。
  void deleteBill(Bill bill) {
    final id = bill.id;
    if (id == null) return;
    bills = bills.where((b) => b.id != id).toList();
    _notifyData();
    _mutate(() async {
      await repo.softDelete(id);
      bills = await repo.loadBills();
    });
  }

  void undoDelete(Bill bill) {
    final id = bill.id;
    if (id == null) return;
    _mutate(() async {
      await repo.undelete(id);
      bills = await repo.loadBills();
    });
  }

  // ═══ 预算 ═════════════════════════════════════════════

  int budgetOf(String monthKey) => budgets[monthKey] ?? 0;

  void setBudget(String monthKey, int cents) {
    _mutate(() async {
      if (cents <= 0) {
        budgets.remove(monthKey);
        await repo.removeBudget(monthKey);
      } else {
        budgets[monthKey] = cents;
        await repo.upsertBudget(monthKey, cents);
      }
    });
  }

  // ═══ 流水视图（直译模拟版翻页 / 粒度切换） ═════════════

  DataRange get dataRange => DataRange.of(bills);

  List<Bill> billsOfView() {
    final v = billView;
    // bills 自身已由 repo 的 `ORDER BY date DESC, created_at DESC` 与
    // saveBill 的插入排序维持倒序，过滤不会破坏次序 —— 这里不再重复排序
    // （原实现在每次 build 里做一次 O(n log n)，是滚动掉帧的来源之一）。
    return v.mode == 'month'
        ? bills.where((b) => monthKeyOf(b.date) == v.month).toList()
        : bills.where((b) => b.date == v.date).toList();
  }

  void shiftView(int delta) {
    final v = billView;
    final t = todayInt();
    final rng = dataRange;
    if (v.mode == 'month') {
      final next = monthKeyShift(v.month, delta);
      if (next.compareTo(todayMonthKey()) > 0 ||
          next.compareTo(rng.minMonth) < 0) {
        return; // 越界
      }
      v.month = next;
    } else {
      final d = dtOf(v.date).add(Duration(days: delta));
      final next = dateIntOf(d);
      if (next > t || next < rng.minDate) return;
      v.date = next;
    }
    _notifyData();
  }

  void switchGrain(String target) {
    final v = billView;
    if (v.mode == target) return;
    if (target == 'month') {
      v.mode = 'month';
      v.month = monthKeyOf(v.date);
    } else {
      v.mode = 'day';
      v.date = v.month == todayMonthKey() ? todayInt() : monthKeyDay(v.month, 1);
    }
    _notifyData();
  }

  void selectDate(int dateInt) {
    billView.mode = 'day';
    billView.date = dateInt;
    billView.month = monthKeyOf(dateInt);
    _notifyData();
  }

  void selectMonth(String monthKey) {
    billView.mode = 'month';
    billView.month = monthKey;
    _notifyData();
  }

  void backToToday() {
    if (billView.mode == 'month') {
      billView.month = todayMonthKey();
    } else {
      billView.date = todayInt();
    }
    _notifyData();
  }

  // ═══ 统计聚合（数据全量在内存，直译模拟版；万级数据切 SQL 见 README） ═══

  /// 当前统计基准月：最新一笔账单所在月（无账单 = 当月），直译模拟版 activeMonth
  String get activeMonth {
    if (bills.isEmpty) return todayMonthKey();
    return monthKeyOf(bills.first.date); // bills 已按 date DESC 排序
  }

  List<Bill> billsOfMonth(String monthKey) =>
      bills.where((b) => monthKeyOf(b.date) == monthKey).toList();

  List<CategoryTotal> expenseByCategoryOfMonth(String monthKey) {
    final from = monthKeyDay(monthKey, 1);
    final to = monthKeyDay(monthKey, 31);
    return _categoryTotals(from, to);
  }

  List<CategoryTotal> expenseByCategoryOfYear(int year) =>
      _categoryTotals(year * 10000 + 101, year * 10000 + 1231);

  List<CategoryTotal> _categoryTotals(int from, int to) {
    final map = <String, int>{};
    for (final b in bills) {
      if (!b.isIncome && b.date >= from && b.date <= to) {
        map[b.categoryId] = (map[b.categoryId] ?? 0) + b.amount;
      }
    }
    final rows = [
      for (final e in map.entries) CategoryTotal(e.key, e.value),
    ]..sort((a, b) => b.cents.compareTo(a.cents));
    return rows;
  }

  /// 年视图 12 个月收支（双柱数据）
  List<MonthSum> monthlySumsOfYear(int year) {
    final sums = List<MonthSum>.generate(12, (_) => const MonthSum(0, 0));
    for (final b in bills) {
      if (b.date ~/ 10000 != year) continue;
      final m = (b.date % 10000) ~/ 100 - 1;
      if (m < 0 || m > 11) continue;
      final old = sums[m];
      sums[m] = b.isIncome
          ? MonthSum(old.income + b.amount, old.expense)
          : MonthSum(old.income, old.expense + b.amount);
    }
    return sums;
  }

  /// 月键 → 收支汇总（首页当月结余）
  MonthSum monthSum(String monthKey) => sumUp(billsOfMonth(monthKey));

  // ═══ 备份入口（DataPage 调用） ═════════════════════════

  /// 导出：返回保存的文件名（null = 用户取消）
  Future<String?> exportBackup() => backup.exportBackup(appVersion: appVersion);

  /// 导入：SAF 选文件 → 事务写入 → 刷新内存
  Future<ImportResult?> importBackup({required bool replaceAll}) async {
    final dto = await backup.pickBackup();
    if (dto == null) return null;
    final result = await repo.importBackup(dto, replaceAll: replaceAll);
    await reload();
    return result;
  }

  Future<BackupDto> readAutoBackupFile(File file) =>
      backup.readAutoBackup(file);

  Future<ImportResult> importBackupDto(BackupDto dto,
          {required bool replaceAll}) async =>
      repo.importBackup(dto, replaceAll: replaceAll).then((r) async {
        await reload();
        return r;
      });

  Future<List<File>> listAutoBackups() => backup.listAutoBackups();

  Future<void> reload() async {
    bills = await repo.loadBills();
    budgets = await repo.loadBudgets();
    categories = await repo.loadCategories();
    categoryMap = {for (final c in categories) c.id: c};
    await _refreshWealth();
    _notifyData();
  }

  // ═══ 底层 ═════════════════════════════════════════════

  void switchTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  /// 数据变更统一通道：**串行执行** + 完成后刷新聚合 + 防抖自动备份。
  ///
  /// 串行化是必要的：连续快速记两笔会并发触发 insert + 全量 reload，
  /// 交错时后完成的 reload 可能带着较旧快照覆盖内存，表现为「刚记的账闪一下没了」。
  /// 这里用 Future 链把写入排成队列，队列内部自行捕获异常，链不会断。
  Future<void> _mutate(Future<void> Function() action) {
    final next = _mutateTail.then((_) async {
      try {
        await action();
        await _refreshWealth();
      } catch (e) {
        // 调用方（UI）多为 fire-and-forget，异常必须在此收敛，
        // 否则会变成未捕获的异步异常（release 静默、debug 红屏）。
        // ignore: avoid_print
        print('[VM] 数据写入失败：$e');
      }
      _notifyData();
      _scheduleAutoBackup();
    });
    _mutateTail = next;
    return next;
  }

  Future<void> _mutateTail = Future<void>.value();

  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer(const Duration(milliseconds: 800), () {
      backup.writeAutoBackup(appVersion: appVersion);
    });
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    formRev.dispose();
    super.dispose();
  }

  /// 供「关于」页展示
  int get dbVersion => AppDb.version;
}
