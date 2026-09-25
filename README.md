# 记账本 · 国风 Android 版

基于模拟版原型（`../index.html`）与落地方案（`../优化与Android落地方案.md`）实现的 Flutter 应用。
目标设备 OPPO Find X8 Ultra，同时兼容 Android 6.0+（minSdk 23）。

- 视觉：宣纸底 / 浓墨字 / 朱砂主题 / 描金辅助 / 宋体标题，与模拟版一致
- 数据：**纯离线 · 零权限 · 不联网**（隐私即卖点）
- 技术栈：Flutter + Provider + sqflite（SQLite）+ SAF 文件选择器备份

---

## 一、编译与运行

### 1. 环境要求

| 项 | 要求 |
|---|---|
| Flutter | stable **≥ 3.24**（`ShellPage` 用了 3.24 引入的 `PopScope.onPopInvokedWithResult`） |
| JDK | 17（AGP 8.7.3 硬性要求） |
| Android SDK | API 35 + Command-line Tools + Platform-Tools |
| Gradle / AGP / Kotlin | 8.9 / 8.7.3 / 2.0.21（工程已配置，首次构建自动下载） |

### 2. 构建（脚手架已完整，无需再 `flutter create`）

本仓库包含全部 `lib/` 源码、`android/` 配置、应用图标
（`mipmap-*` 朱砂方章，生成脚本见 `tool/gen_icons.py`）
以及 **Gradle wrapper 三件套**（`gradlew` / `gradlew.bat` / `gradle/wrapper/gradle-wrapper.jar`，对齐 Gradle 8.9）。

```bash
flutter pub get

# 开发调试（连接 Find X8 Ultra，开启 USB 调试）
flutter run

# 通用包：任何机型可装（个人直装推荐）
flutter build apk --release

# 分 ABI 包：体积约 −40%
flutter build apk --release --split-per-abi
# 产物：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

把 APK 传到手机安装即可（首次需在「设置 → 安全」允许安装未知来源应用）。
完整安装步骤、ColorOS 放行、签名密钥配置见仓库根目录
**《安装与打包说明.md》**。

> **签名**：`android/app/build.gradle.kts` 会在存在 `android/key.properties` 时
> 自动启用 release 签名，否则回退 debug 签名。debug 签名的 APK 换台电脑就
> 无法覆盖安装（只能卸载，数据丢失），长期使用请先生成固定密钥 —— 步骤见
> 《安装与打包说明.md》第三章 3.3。
> 上架商店另需修改 `applicationId`（当前为 `com.example.ledger`）。

---

## 二、项目结构（四层 · 单向数据流）

```
lib/
├── main.dart                      # 入口：edge-to-edge、本地化、初始化 ViewModel
├── theme/
│   └── palette.dart               # 国风设计令牌（与模拟版 CSS 变量一一对应）
├── utils/
│   ├── dates.dart                 # 日期工具：全部本地日历语义（yyyyMMdd 整数）
│   └── money.dart                 # 金额工具：存储单位为「分」（int）
├── models/                        # 领域模型（纯 Dart，无 Flutter 依赖可单测）
│   ├── bill.dart                  #   账单 + validBill 结构校验
│   ├── category.dart              #   分类 / 资金账户
│   ├── budget.dart                #   月度预算
│   └── backup.dart                #   备份 DTO + schemaVersion 校验（Isolate 解析）
├── data/
│   ├── app_db.dart                # SQLite 封装：版本管理 + 迁移链 v1→v4
│   ├── bill_repository.dart       # 数据仓库接口 + sqflite 实现（SQL 聚合下推）
│   ├── backup_service.dart        # SAF 导出/导入 + 自动备份（原子写 + 每日留档）
│   └── seed.dart                  # 19 内置分类种子 + 演示数据（直译模拟版）
├── viewmodel/
│   └── ledger_view_model.dart     # 状态层：表单/流水游标/预算/聚合/软删撤销
├── widgets/                       # 国风组件（全自绘，零图表三方库）
│   ├── paper.dart                 #   宣纸背景 + 面板卡
│   ├── number_keyboard.dart       #   自绘数字键盘（触感 + 长按连删）
│   ├── calendar_dialog.dart       #   日历弹层（月历/年历，三色圆点）
│   ├── donut_chart.dart           #   环形图 CustomPainter（参数直译模拟版）
│   ├── bar_rank.dart              #   分类排行条形图
│   ├── year_bars.dart             #   年 12 月双柱图
│   ├── budget_bar.dart            #   预算条（5 级预警色 + >250% 脉动）
│   ├── modal_input.dart           #   可编辑数字弹层（预算）
│   ├── bill_tile.dart             #   账单行（滑删 + 撤销）
│   ├── fit_text.dart              #   金额自适应降字号（fitAmount）
│   └── toast.dart                 #   国风 Toast / 撤销 Toast
└── pages/
    ├── shell_page.dart            # 三页壳 + 印章 FAB + 首启引导
    ├── home_page.dart             # 首页：净资产卡 / 当月结余 / 日·月流水
    ├── add_page.dart              # 记账页：键盘 / 分类 / 预览条
    ├── stat_page.dart             # 统计页：月环形 / 年双柱 / 排行
    └── data_page.dart             # 数据管理：备份 / 恢复 / 关于
```

分层约定：

- **UI 层**（pages/widgets）：只读状态、上报事件，不做业务计算
- **状态层**（ViewModel）：业务规则唯一出处（键盘输入规则、借贷净额、翻页边界…）
- **数据层**（Repository 接口）：领域层只认接口，可替换内存假实现做测试；
  未来加云同步时新增实现类即可，UI 层零改动
- **聚合下推**：净资产 / 分类占比走 SQL `SUM + GROUP BY`（万级数据 <10ms）
  —— 统计页当前走内存聚合（数据已全量在内存），数据量超万级时把
  `LedgerViewModel.expenseByCategoryOfMonth` 换成 `repo.expenseByCategory` 即可，方法已就绪

---

## 三、数据存储设计

### 3.1 存储口径（落地方案 3.4 三决策）

| 决策 | 内容 | 原因 |
|---|---|---|
| 金额存「分」 | `38.5 元 → 3850`（INTEGER） | 根治 `0.1+0.2≠0.3` 浮点误差 |
| 日期存 `yyyyMMdd` 整数 | `20260925` | 本地日历语义，规避 UTC 跨日错位；区间查询友好 |
| 云同步预留 | `uuid` 幂等键 + `deleted` 软删 + `updated_at` | v1 不启用同步但不留死角 |

### 3.2 Schema 与迁移链（当前 v4）

```
bill        id, uuid(UNIQUE), type, amount(分), category_id, note,
            date(yyyyMMdd), account_id, deleted, created_at, updated_at
category    id(TEXT PK), name, icon, bg, type, sort, is_custom   ← 19 内置分类
account     id, name, icon, sort                                  ← 默认「现金」
budget      month('yyyy-MM' PK), cents
索引        idx_bill_uuid / idx_bill_date / idx_bill_cat / idx_category_type_sort
```

**版本演进**（`data/app_db.dart` 唯一出处，真实迁移链示例）：

| 版本 | 变更 | 策略 |
|---|---|---|
| v1 | bill 基础表 | 初版 |
| v2 | + uuid / updated_at / deleted + budget 表 | `ALTER TABLE ADD COLUMN` + `UPDATE` 回填，禁止 drop 表 |
| v3 | + account 表 + account_id + 索引 | 同上 |
| v4 | + **category 表**（v1–v3 遗漏，`ensureSeeded` 一直依赖它） | `CREATE TABLE IF NOT EXISTS`，幂等 |

- **老用户升级**：`onUpgrade` 依序执行跨过的迁移片段，**旧数据完整保留**
- **新装用户**：`onCreate` 回放全部片段直接得到最新结构
- **事务**：sqflite 的 `onCreate`/`onUpgrade` **本身就在排他事务里**，
  代码里不再嵌套 `db.transaction`（避免「假事务」包装）；片段抛异常即整体回滚
- **降级**：`onDowngrade` 保留数据不删表（比 sqflite 默认的删表策略安全）
- **后续加字段标准三步**：① `kCurrentSchemaVersion` +1 ② 新增 `_migrateV5`
  ③ `_runMigration` 加 `case 5`。禁止修改已发布的历史片段

### 3.3 备份与恢复

| 能力 | 实现 |
|---|---|
| 手动导出 | JSON 全量（账单 + 预算 + 分类 + 账户 + meta），SAF 系统文件选择器保存，**零存储权限** |
| 手动导入 | Isolate 解析 → 字段级校验（validBill 直译）→ 事务写入，失败整体回滚 |
| 合并模式 | 按 uuid 去重，同编号覆盖，保留现有数据 |
| 覆盖模式 | 清空后导入（二次确认） |
| 向下兼容 | `meta.schemaVersion > 当前版本` 时拒绝导入并提示升级 App |
| 自动备份 | 每次数据变更 800ms 防抖写入应用私有目录：`latest.json`（原子写）+ 每日留档 ≤31 份；「数据管理」页可一键恢复 |

### 3.4 软删除与撤销

账单删除是 `deleted=1` 软删（物理数据保留），Toast 5 秒内可撤销；
同时软删也是未来云同步「last-write-wins」的删除标记。

---

## 四、与模拟版的功能对照

| 模拟版能力 | Android 版实现 | 差异说明 |
|---|---|---|
| 净资产 = 现金 − 净债务 | SQL 聚合直译 debtNet | 一致 |
| 预算 5 级预警 + 脉动 | `BudgetBar` 直译 | 一致 |
| 日/月双粒度流水 + 日历 | 直译，含三色圆点/印章选中/未来禁用 | 一致 |
| 自绘键盘（2 位小数/9 位上限/前导 0） | 直译 + 触感反馈 + 长按连删 | 增强 |
| 环形图（−90° 起始/0.028rad 缝/环宽 46@2x） | CustomPainter 直译 | 一致 |
| 点行展开删除 | 改为右滑删除 + 撤销 Toast | 按 Android 习惯 + 方案 P0 |
| 首启自动注入示例数据 | 改为首启引导二选一 | 方案 P0：不污染真实账本 |
| 日历「本月/今天」语义重复 | 「本月」= 当月 1 号 | 按方案 P0 修正 |
| localStorage 单 key 数组 | SQLite 四表 schema 化 | 根治「清缓存/换机全丢」 |

---

## 五、版本迭代指南

### 5.1 版本号管理

只改 `pubspec.yaml` 一处：`version: 1.0.0+1`（`major.minor.patch+build`）。
`build`（= versionCode）必须单调递增，否则安装器拒绝覆盖升级；
Android 端 gradle 自动读取，无需改两处。

### 5.2 数据结构变更的向下兼容

见「3.2 迁移链」的标准三步；同时注意备份侧：
导出时写入当前 `schemaVersion`，导入时校验，保证「新版备份不被旧版 App 误读」。

### 5.3 功能扩展点（已预留）

| 扩展 | 落点 |
|---|---|
| 账单编辑（P0） | `BillTile.onTap` 已留占位 → 回填 `form` + `repo.insertBill`（uuid 幂等） |
| 账户体系（P1） | `account` 表 + `bill.account_id` 已就绪，记账页加账户选择即可 |
| 自定义分类（P2） | `category` 表 `is_custom` 字段已就绪 |
| 搜索筛选（P1） | 新增 `repo.search()` SQL，UI 加搜索页 |
| 云同步（v2） | `uuid/deleted/updated_at` 已就绪；新增 `CloudBillRepository implements BillRepository` |
| 状态层升级 Riverpod | 仅影响 `viewmodel/`，UI 层通过 Provider 读取的方式不变 |
| 内嵌思源宋体 | 见 `pubspec.yaml` 注释，防厂商 ROM 字体回退 |

### 5.4 真机验收清单（Find X8 Ultra）

- [ ] 首启引导 → 写入演示数据 → 首页三卡数值正确（净资产 = 现金 − 净债务）
- [ ] 记一笔 → 340ms 回首页并定位该日 → 净资产/预算/统计同步刷新
- [ ] 账单行**左滑露出「删除」→ 再点「删除」**才删除 → 撤销可恢复
- [ ] 底部标签栏上下无黑边（含记账页键盘弹起时）
- [ ] 日/月切换 + 日历选历史日期 + 翻页边界（最早账单日 ~ 今天）
- [ ] 统计页月/年切换 + 点中间标签开日历选月/选年
- [ ] 设预算 → 进度条 5 级色随用量变化
- [ ] 导出备份 → 卸载重装 → 导入恢复 → 数据一致
- [ ] 安装 v1 → 升级新版（改 version）→ 旧数据完整 + `onUpgrade` 迁移生效

---

## 六、代码审核修复记录（2026-09-25）

首轮全量静态审核（构建环境未就绪，未做编译验证）发现并修复：

| 级别 | 问题 | 影响 | 修复 |
|---|---|---|---|
| **P0** | `category` 表在 v1–v3 迁移中**从未创建**，而 `ensureSeeded()` / `loadCategories()` 一直依赖它 | `init()` 抛 `no such table: category`，应用**永久停在加载圈，完全不可用** | 新增 v4 迁移建表（`IF NOT EXISTS` 幂等），`kCurrentSchemaVersion` → 4 |
| **P0** | 退格键：`''.substring(0, -1)` | 空金额时按退格 → `RangeError` **崩溃** | `handleKey('back')` 加空缓冲早返回 |
| **P0** | `gradle-wrapper.jar` / `gradlew` / `gradlew.bat` 缺失 | 本地与 CI 构建均直接失败 | 从 Gradle v8.9.0 官方仓库补齐 |
| **P1** | 删除后等异步落库才刷新列表 | 中间任何 rebuild 触发 `A dismissed Dismissible widget is still part of the tree` 断言 | `deleteBill` 先同步从内存移除并通知，再异步落库 |
| **P1** | `saveBill` 后列表未即时包含新账单 | 回首页后新账「闪一下才出现」 | 乐观插入 + 统一按 `date DESC, createdAt DESC` 排序 |
| **P1** | `_mutate` 未串行，异常无人接收 | 连记两笔可能被旧快照覆盖；失败时为未捕获异步异常 | Future 链串行 + 内部 try/catch |
| **P1** | 初始化失败只打日志 | 用户面对永久加载圈，无从判断 | `initError` + `ShellPage` 错误态（原因 + 重试） |
| **P1** | 统计页默认月 = **系统当前月**，首页 = **最新账单月** | 跨月未记账时两页口径打架，统计页空图 | 统计页初始游标对齐 `activeMonth`，并加区间夹取 |
| **P2** | 月粒度下开日历用 `v.date` 而非 `v.month` | 翻月后日历始终停在切换那一刻的月份 | 改用 `v.month` 解析年月 |
| **P2** | 记账页 `resizeToAvoidBottomInset: true` + 固定高度自绘键盘 | 点备注唤起系统键盘 → 窄屏/大字体 RenderFlex overflow | 改为 `false`，并加 `onTapOutside` / `onSubmitted` 收键盘 |
| **P2** | 横屏未处理 | 记账页固定部分约 710dp > 横屏可用高度 → 溢出 | Manifest 锁 `screenOrientation="portrait"` |
| **P2** | 导出成功后 Toast 显示 SAF 的 `content://…` URI | 用户看不懂、也找不到文件 | `exportBackup` 回传可读文件名 |
| **P2** | release 只有 debug 签名 | 换电脑重建即无法覆盖安装，只能卸载丢数据 | 支持 `key.properties` + 正式签名，缺省回退 debug |
| **P3** | `sqlite onCreate/onUpgrade` 内再包 `db.transaction` | sqflite 会给「假事务」包装，语义冗余易误判 | 去掉嵌套（回调本身已在排他事务内） |
| **P3** | 系统返回键直接退出 App | 在记账页/统计页误按即退出 | `PopScope`：非首页先回首页 |
| **P3** | `_normalizeFormCategory` 对空 `categories` 取 `.first` | 种子异常时二次崩溃 | 空列表早返回 |
| **P3** | 备份 JSON 解析大量 `as String` / `as num` 硬转 | 用户手改备份文件（类型不符）会在 Isolate 内抛 TypeError，错误信息无意义 | 宽容转换 `_str` / `_int` / `_toInt`，兜底到默认值 |

**未做编译验证**：本机无 Flutter / JDK / Android SDK，以上均为静态审核结论。
已完成的替代验证：29 个 `.dart` 文件括号/字符串结构平衡检查、6 个 XML 解析、工作流 YAML 结构检查 —— 全部通过。
首次构建请按《安装与打包说明.md》第六章 8 项清单过一遍真机。

---

## 七、真机反馈修复（第二轮 · 2026-09-25）

装机实测后用户反馈 11 项问题，逐项定位到代码事实后修复（`version: 1.0.0+2`）：

| # | 现象 | 根因 | 修复 |
|---|---|---|---|
| 1 | 空账本提示不在屏幕中央 | 空态是滚动内容的一部分，只跟在日期栏下方 | 首页改 `CustomScrollView`，空态用 `SliverFillRemaining(hasScrollBody: false)` 撑满剩余视口并垂直居中 |
| 2 | 账单页加号附近发黑 | **Scaffold 默认 `resizeToAvoidBottomInset: true`**，body 按 `viewInsets.bottom` 收窄，缝隙处露出 Flutter Surface 的未绘制区（真机为黑）；标签栏原为 `0xEB` 半透，叠在黑色上发灰 | 首页/统计页也关掉该开关（记账页本就是 false）；外壳 Scaffold 底色改不透明 `screenBg`，标签栏改不透明；主题 `scaffoldBackgroundColor` 兜底 |
| 3 | 金额光标与数字不对齐 | 光标是 `Row(baseline)` 里的 `Container`，**无基线子项被 Flex 按 cross-start 摆放** → 光标整体高出数字 | 改为用 `TextPainter.computeDistanceToActualBaseline` 实测基线，`¥`/数字/光标三者在 `Stack` 里按度量定位，光标 bottom 边距 = 下伸缩部高度 |
| 4 | 选中分类图标上边框被切 | 选中态 `AnimatedContainer` 上移 2px，而 `ListView` 视口从 0 开始 → 顶部 2px 被裁 | 分类列表顶部留 5px 内边距（高度 76→82） |
| 5 | 备注/日期栏被下方遮挡 | 行高偏大，系统键盘弹起时压到输入行 | 行内边距 13→8、字号 15→14.5、标签 44px；金额卡内边距 17→12；整条输入区上移约 40px |
| 6 | 账单页日/月按钮样式与统计页不一致 | 两页各写一套段控（金浅底高亮 vs 白卡抬起） | 抽出 `widgets/grain_switch.dart` 共用 |
| 7 | 当月结余字号大于净资产 | 净资产有自适应降字号，大额时被压到 26 而结余固定 34 → 层级反转 | 净资产 44/下限 30、结余 28/下限 18，**恒有结余 < 净资产** |
| 8 | 统计页不能选月份/年份 | 只有 `‹ ›` 步进器 | 步进器中间可点 → 复用日历；`CalendarGrain` 增加 `year`（12 年宫格），`showLedgerCalendar` 支持三种粒度 |
| 9 | 日历「本月」紧贴图例「都有」 | 图例与按钮之间仅一个 `Spacer`，系统字体放大后 Spacer 被吃光 | 图例改 `Expanded + Wrap`（空间不足自动折行），并与按钮间固定留 14px |
| 10 | 运行卡顿 | ① 记账页每次按键 `notifyListeners()` → 首页/统计页（含环形图、排行、双柱）整棵重建；② 宣纸底 260+ 条 `drawLine` 每帧重录；③ `billsOfView()` 每次 build 重复排序；④ 结余卡一次 build 扫两遍账单；⑤ 光标定时器在后台也跑 | ① VM 增 `formRev`（`ValueNotifier`），表单变化只通知它，记账页用 `ValueListenableBuilder` 订阅；② 宣纸底加 `RepaintBoundary` + `isComplex`；③ 去掉重复排序（`bills` 本就有序）；④ 单次扫描；⑤ 非当前页停掉定时器 |
| 11 | 左划直接删除 | `Dismissible` 滑到底即 `onDismissed` | 改为自绘「左滑露出删除条 → 点一下才删」：跟手拖动 + 速度/位移吸附，展开后点行内容只收起；仍走软删 + 撤销 Toast |

**验证方式**：从用户提供的两张真机截图做像素级反推（872×1920，按 FAB 直径 50dp 定标≈2.22px/dp）
—— 量出黑带高度 82px≈37dp、标签栏上沿与 FAB 圆心重合于 `contentBottom`，据此锁定第 2 项根因；
结合 Flutter 3.27.4 源码（`scaffold.dart` 的 `contentBottom = bottom − max(minInsets.bottom, bottomWidgetsHeight)`、
flex.dart 的 baseline 分支、text_painter.dart 的 `computeDistanceToActualBaseline` 签名）确认修复方向。
`flutter analyze` 在 CI 上通过（无新增 issue）。
