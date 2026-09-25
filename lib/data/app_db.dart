import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/backup.dart' show kCurrentSchemaVersion;

/// SQLite 封装 —— 数据库版本管理与迁移的唯一出处。
///
/// ## 版本演进（真实迁移链，可作为后续升级模板）
///
/// | 版本 | 变更 | 迁移策略 |
/// |---|---|---|
/// | v1 | bill 基础表（id/type/amount/category_id/note/date/created_at） | 初版 |
/// | v2 | + uuid（回填后建唯一索引）/ updated_at / deleted 软删 + budget 表 | `ALTER TABLE ADD COLUMN` + `UPDATE` 回填，禁止 drop 表 |
/// | v3 | + account 表 + bill.account_id（资金账户扩展点）+ date/category 索引 | 同上 |
/// | v4 | + category 表（19 内置分类 / 自定义分类 / 账户体系的 JOIN 目标） | 补建遗漏表，**幂等**（IF NOT EXISTS） |
///
/// > v4 说明：`category` 表在 v1–v3 中被遗漏，而 `ensureSeeded()` / `loadCategories()`
/// > 自始依赖它 —— 缺表会让 `init()` 抛 `no such table: category`，应用永久停在加载态。
/// > 该片段用 `IF NOT EXISTS` 保证重复执行安全。
///
/// ## 升级 / 降级行为
/// - **升级**（老用户装新版）：`onUpgrade` 依序执行跨过的迁移片段，旧数据完整保留
///   —— 这是「应用升级后旧数据平滑迁移」的机制保证。
/// - **降级**（新版本数据被老版本打开）：`onDowngrade` 保留数据不删表，
///   老代码因多列 SELECT 报错时用户需升级 App（比默认的删表策略安全）。
/// - **新装**：`onCreate` 依序回放全部迁移片段，直接得到最新结构。
///
/// ## 事务语义（重要）
/// sqflite 的 `onCreate` / `onUpgrade` / `onDowngrade` **已在排他事务内**执行
/// （见 sqflite_common `database_mixin.dart` 的 `openDatabase`），
/// 因此这里**不再嵌套 `db.transaction`** —— 既避免「假事务」包装，也避免
/// 误以为失败会回滚两层。任一迁移片段抛异常 → 整个 open 事务回滚，库保持原状。
///
/// ## 后续加字段的标准三步（示例：v5 加备注提醒时间）
/// 1. `version`（= `kCurrentSchemaVersion`）改 5；2. 增加 `_migrateV5`；
/// 3. `_runMigration` 的 `case 5` 分支。禁止修改历史片段。
class AppDb {
  AppDb._();

  static const String name = 'ledger.db';
  static const int version = kCurrentSchemaVersion;

  static Database? _db;

  /// 全局单例（账本应用单进程访问，足够；多 isolate 需重新评估）
  static Future<Database> instance() async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, name),
      version: version,
      // 注意：onCreate / onUpgrade 已运行在 sqflite 的排他事务中，
      // 这里**不要**再包 db.transaction（会得到「假事务」包装，语义冗余）。
      onCreate: (db, v) async {
        // 新装用户：依序回放全部历史迁移，等价于「老库一路升上来」
        for (var i = 1; i <= v; i++) {
          await _runMigration(db, i);
        }
      },
      onUpgrade: (db, oldV, newV) async {
        // 老用户升级：只执行跨过的版本片段，数据原样保留
        for (var i = oldV + 1; i <= newV; i++) {
          await _runMigration(db, i);
        }
      },
      // 降级（旧 App 打开新库）：保数据、不删表，提示升级
      onDowngrade: (db, oldV, newV) {
        // ignore: avoid_print
        print('[AppDb] 数据库从 v$oldV 降级到 v$newV：保留数据。'
            '若功能异常请升级 App（数据未删除）。');
      },
    );
  }

  /// 执行第 [to] 个版本的迁移片段
  static Future<void> _runMigration(DatabaseExecutor db, int to) async {
    switch (to) {
      case 1:
        await _migrateV1(db);
        break;
      case 2:
        await _migrateV2(db);
        break;
      case 3:
        await _migrateV3(db);
        break;
      case 4:
        await _migrateV4(db);
        break;
      default:
        throw StateError('未定义的数据库迁移片段 v$to');
    }
  }

  // ── v1：初版账单表 ───────────────────────────────────────
  static const String _v1Bill = '''
    CREATE TABLE bill (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      type        TEXT NOT NULL CHECK(type IN ('income','expense')),
      amount      INTEGER NOT NULL,               -- 单位：分；负数 = 冲销
      category_id TEXT NOT NULL,
      note        TEXT,
      date        INTEGER NOT NULL,               -- yyyyMMdd
      created_at  INTEGER NOT NULL
    )''';

  static Future<void> _migrateV1(DatabaseExecutor db) async {
    await db.execute(_v1Bill);
  }

  // ── v2：云同步预留字段 + 预算表 ───────────────────────────
  static Future<void> _migrateV2(DatabaseExecutor db) async {
    // SQLite 不支持 ADD COLUMN 带 UNIQUE，先加列 → 回填 → 建唯一索引
    await db.execute('ALTER TABLE bill ADD COLUMN uuid TEXT');
    await db.execute(
        "UPDATE bill SET uuid = 'legacy-' || id WHERE uuid IS NULL OR uuid = ''");
    await db.execute('CREATE UNIQUE INDEX idx_bill_uuid ON bill(uuid)');

    await db.execute(
        'ALTER TABLE bill ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
    await db.execute(
        'UPDATE bill SET updated_at = created_at WHERE updated_at = 0');

    await db.execute(
        'ALTER TABLE bill ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');

    await db.execute('''
      CREATE TABLE budget (
        month TEXT PRIMARY KEY,                   -- 'yyyy-MM'
        cents INTEGER NOT NULL
      )''');
  }

  // ── v3：资金账户 + 索引 ──────────────────────────────────
  static Future<void> _migrateV3(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE account (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        sort INTEGER DEFAULT 0
      )''');
    await db.execute(
        "INSERT OR IGNORE INTO account (id, name, icon, sort) VALUES (1, '现金', '💵', 0)");
    await db.execute(
        'ALTER TABLE bill ADD COLUMN account_id INTEGER NOT NULL DEFAULT 1');

    // 查询热路径索引（统计页 date 过滤 / 分类聚合）
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bill_date ON bill(date DESC, id DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_cat ON bill(category_id, date)');
  }

  // ── v4：补建 category 表 ─────────────────────────────────
  //
  // v1–v3 漏建此表，而 Seed / loadCategories / 统计图例全都依赖它。
  // 用 IF NOT EXISTS 写成幂等片段：无论库此前处于哪一版，执行后结构一致。
  static const String _v4Category = '''
    CREATE TABLE IF NOT EXISTS category (
      id        TEXT PRIMARY KEY,               -- 'food' / 'salary' / 自定义 id
      name      TEXT NOT NULL,
      icon      TEXT NOT NULL,                  -- emoji
      bg        INTEGER NOT NULL DEFAULT 4294834676,  -- 0xFFFDF9F4 图标底色
      type      TEXT NOT NULL CHECK(type IN ('income','expense')),
      sort      INTEGER NOT NULL DEFAULT 0,
      is_custom INTEGER NOT NULL DEFAULT 0
    )''';

  static Future<void> _migrateV4(DatabaseExecutor db) async {
    await db.execute(_v4Category);
    // 分类按钮横向列表按 type 过滤 + sort 排序
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_category_type_sort ON category(type, sort)');
    // 注：19 个内置分类由 SqfliteBillRepository.ensureSeeded() 以
    // INSERT OR IGNORE 幂等写入（本片段只负责建结构，不掺数据）。
  }
}
