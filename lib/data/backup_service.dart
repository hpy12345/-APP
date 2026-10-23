import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/backup.dart';
import '../utils/dates.dart';
import 'app_db.dart';
import 'bill_repository.dart';
import 'storage_stat.dart';

/// 备份与恢复服务。
///
/// - **导出**：走系统文件选择器（SAF）让用户选保存位置 —— 零存储权限（落地方案 3.7）
/// - **导入**：SAF 选文件 → Isolate 解析校验 → Repository 事务写入，失败回滚
/// - **自动备份**：每次数据变更后写入应用私有目录（latest 快照 + 每日留档），
///   卸载重装后库损坏 / 误操作时可从「数据管理」页恢复
class BackupService {
  final BillRepository repo;
  BackupService(this.repo);

  // ── 手动导出（SAF 保存） ─────────────────────────────────

  /// 返回**可读的文件名**（供 Toast 提示）；用户取消返回 null。
  ///
  /// 为什么不回传 `saveFile` 的返回值：Android 上它给的是 SAF 的
  /// `content://…` URI（形如 `content://…/msf%3A1000000042`），
  /// 直接展示对用户零信息量；文件名是我们自己拼的，一定可读。
  ///
  /// 为什么 `type: FileType.any` 而不是 `custom + ['json']`：
  /// Android 的保存/选择对话框是**按 MIME 过滤**的，而 .json 在不同 ROM /
  /// 文件管理器里上报的 MIME 并不统一（application/json / text/plain /
  /// octet-stream）。声明成 custom+json 后，只要系统那边报的不是
  /// application/json，这类文件就会被判定为「不符」—— 表现为**按钮变灰、
  /// 列表里根本看不见备份文件**，用户看到的就是「这个 app 读不了文件」。
  /// 放开类型不做过滤，靠内容校验（parseBackup）保证只吃自己的备份。
  Future<String?> exportBackup({required String appVersion}) async {
    final dto = await repo.buildBackup(appVersion);
    final json = const JsonEncoder.withIndent('  ').convert(dto.toJson());
    final d = DateTime.now();
    final fileName =
        '记账本备份_${d.year}${_two(d.month)}${_two(d.day)}_${_two(d.hour)}${_two(d.minute)}${_two(d.second)}.json';
    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: utf8.encode(json),
      type: FileType.any,
    );
    return path == null ? null : fileName;
  }

  // ── 手动导入（SAF 选择） ─────────────────────────────────

  /// 用户取消返回 null；文件不可读 / 不是有效备份抛 [FormatException]。
  ///
  /// 三道防线（真机「读不到文件」的三种成因都覆盖）：
  /// ① 不按扩展名/MIME 过滤 —— 否则备份文件在选择器里是灰的（见 [exportBackup] 注释）；
  /// ② `bytes` 拿不到时退回按 `path` 读 —— 部分 ROM 的 provider 只给路径不给字节
  ///    （file_picker 会把选中的文件缓存一份到应用缓存目录，path 一定可用）；
  /// ③ 报错带上文件名与体积，用户复述问题时一眼能定位是哪个文件。
  Future<BackupDto?> pickBackup() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } on PlatformException catch (e) {
      throw FormatException('打不开系统文件选择器：${e.message ?? e.code}');
    }
    if (result == null || result.files.isEmpty) return null; // 用户取消
    final f = result.files.single;

    // 防误选：记账备份都是几十 KB 级，超过 20MB 基本都是选错了（视频/安装包）
    if (f.size > 20 * 1024 * 1024) {
      throw FormatException('「${f.name}」太大（>20MB），不像是记账备份');
    }

    List<int>? bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      final path = f.path;
      if (path != null) {
        try {
          bytes = await File(path).readAsBytes();
        } catch (_) {
          // 失败就交给下面统一报错
        }
      }
    }
    if (bytes == null || bytes.isEmpty) {
      throw FormatException('读不到「${f.name}」，换个文件管理器再选一次');
    }

    try {
      return await parseBackupAsync(
          utf8.decode(bytes, allowMalformed: true));
    } on FormatException catch (e) {
      // 把文件名拼进解析错误里：「xx.json」不是有效的 JSON 文件
      throw FormatException('「${f.name}」${e.message}');
    }
  }

  // ── 自动备份（应用私有目录） ──────────────────────────────

  /// 数据变更后调用（ViewModel 已做 800ms 防抖）。
  /// latest.json 用「写临时文件 + rename」原子替换，断电也不会写半个 JSON。
  Future<void> writeAutoBackup({required String appVersion}) async {
    try {
      final dir = await _autoDir();
      final dto = await repo.buildBackup(appVersion);
      final json = const JsonEncoder().convert(dto.toJson());
      final tmp = File(p.join(dir.path, 'latest.tmp'));
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(p.join(dir.path, 'latest.json'));
      // 当日留档（同日覆盖，最多保留 31 份）
      final daily = File(p.join(dir.path, 'backup_${fmtDateDash(todayInt())}.json'));
      await daily.writeAsString(json, flush: true);
      _pruneOldDaily(dir);
    } catch (_) {
      // 自动备份失败不打扰用户（下次变更会再试）
    }
  }

  /// 可恢复的自动备份列表（latest 在前）
  Future<List<File>> listAutoBackups() async {
    final dir = await _autoDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    // latest.json 固定排最前
    files.removeWhere((f) => p.basename(f.path) == 'latest.json');
    files.sort((a, b) => b.path.compareTo(a.path)); // backup_2026-… 倒序
    final latest = File(p.join(dir.path, 'latest.json'));
    if (latest.existsSync()) files.insert(0, latest);
    return files;
  }

  Future<BackupDto> readAutoBackup(File f) async {
    final raw = await f.readAsString();
    return parseBackupAsync(raw);
  }

  /// 本机存储体积：SQLite 主库 + 自动备份目录。
  ///
  /// 只读文件大小（`File.lengthSync()`），不读内容、不外传 —— 与「零权限
  /// 纯离线」的隐私口径一致。任何一步失败都退化成 0，不让「关于」页
  /// 因为一个数字拿不到就崩掉。
  Future<StorageStat> stat() async {
    var dbBytes = 0;
    try {
      final dir = await getDatabasesPath();
      final f = File(p.join(dir, AppDb.name));
      if (f.existsSync()) dbBytes = f.lengthSync();
    } catch (_) {
      // ignore: avoid_print
      print('[BackupService] 读取数据库体积失败');
    }

    var autoBytes = 0;
    var autoCount = 0;
    try {
      for (final f in (await _autoDir()).listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        autoBytes += f.lengthSync();
        autoCount++;
      }
    } catch (_) {
      // ignore: avoid_print
      print('[BackupService] 读取自动备份体积失败');
    }

    return StorageStat(
      dbBytes: dbBytes,
      autoBackupBytes: autoBytes,
      autoBackupCount: autoCount,
    );
  }

  Future<Directory> _autoDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'auto_backups'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 每日留档只保留最近 31 份，防止无限增长
  void _pruneOldDaily(Directory dir) {
    final dailies = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('backup_'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (var i = 31; i < dailies.length; i++) {
      dailies[i].deleteSync();
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
