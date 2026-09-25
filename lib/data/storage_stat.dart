/// 本机存储体积（「数据与关于」页展示）。
///
/// 单独一个文件：BackupService 负责采集、DataPage 负责展示，
/// 双方只需要这个纯数据契约，不必互相 import。
library;

class StorageStat {
  /// SQLite 主库文件字节数
  final int dbBytes;

  /// 自动备份目录合计字节数
  final int autoBackupBytes;

  /// 自动备份份数（latest + 每日留档）
  final int autoBackupCount;

  const StorageStat({
    required this.dbBytes,
    required this.autoBackupBytes,
    required this.autoBackupCount,
  });

  int get totalBytes => dbBytes + autoBackupBytes;

  static const StorageStat empty = StorageStat(
    dbBytes: 0,
    autoBackupBytes: 0,
    autoBackupCount: 0,
  );
}

/// 字节 → 人读文案（账本数据量级不大，保留 1 位小数足够）
String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 2 : 1)} MB';
}
