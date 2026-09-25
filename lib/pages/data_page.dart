import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../theme/palette.dart';
import '../utils/dates.dart';
import '../viewmodel/ledger_view_model.dart';
import '../widgets/paper.dart';
import '../widgets/toast.dart';

/// 数据管理页：备份 / 恢复 / 自动备份 / 关于。
///
/// - 导出：JSON 全量（含分类配置），SAF 系统文件选择器保存，零权限
/// - 导入：合并（按 uuid 去重）或覆盖（清空后导入，二次确认）
/// - 自动备份：应用私有目录 latest 快照 + 每日留档（≤31 份）
class DataPage extends StatelessWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LedgerViewModel>();
    final rng = vm.dataRange;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 头部
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 20, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Palette.text, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('数据与关于',
                        style: serifStyle.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      // ── 数据概览 ──
                      PanelCard(
                        title: '数据概览',
                        child: Column(
                          children: [
                            _infoRow('账单', '${vm.bills.length} 笔'),
                            _infoRow('月度预算', '${vm.budgets.length} 条'),
                            _infoRow(
                              '覆盖范围',
                              vm.bills.isEmpty
                                  ? '暂无数据'
                                  : '${fmtDateDash(rng.minDate)} ~ ${fmtDateDash(rng.maxDate)}',
                            ),
                            _infoRow('存储位置', '本机 SQLite（纯离线，零权限）'),
                          ],
                        ),
                      ),

                      // ── 备份与恢复 ──
                      PanelCard(
                        title: '备份与恢复',
                        child: Column(
                          children: [
                            _actionRow(
                              icon: Icons.upload_outlined,
                              title: '导出备份',
                              subtitle:
                                  'JSON 全量（含分类配置）· 系统文件选择器保存',
                              onTap: () => _export(context, vm),
                            ),
                            const Divider(height: 20, color: Palette.line),
                            _actionRow(
                              icon: Icons.download_outlined,
                              title: '导入备份',
                              subtitle:
                                  '合并：按账单编号去重 · 覆盖：清空后导入',
                              onTap: () => _pickImportMode(context, vm),
                            ),
                            const Divider(height: 20, color: Palette.line),
                            _actionRow(
                              icon: Icons.history_outlined,
                              title: '从自动备份恢复',
                              subtitle:
                                  '每次数据变更自动快照（latest + 每日留档 ≤31 份）',
                              onTap: () => _autoRestore(context, vm),
                            ),
                          ],
                        ),
                      ),

                      // ── 关于 ──
                      PanelCard(
                        title: '关于',
                        child: Column(
                          children: [
                            _infoRow('应用版本', vm.appVersion),
                            _infoRow('数据库版本', 'v${vm.dbVersion}（自动迁移，升级不丢数据）'),
                            _infoRow('数据安全', '金额以「分」整数存储 · 软删除可撤销 · 导入事务化失败回滚'),
                            _infoRow('隐私', '不联网、不上传任何数据'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: serifStyle.copyWith(
                    fontSize: 13,
                    color: Palette.textSub,
                    letterSpacing: 1)),
          ),
          Expanded(
            child: Text(value,
                style: serifStyle.copyWith(fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Palette.goldSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x6BB08D4F)),
              ),
              child: Icon(icon, size: 19, color: Palette.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: serifStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: Palette.textSub,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Palette.textSub),
          ],
        ),
      ),
    );
  }

  // ── 导出 ──
  Future<void> _export(BuildContext context, LedgerViewModel vm) async {
    try {
      final name = await vm.exportBackup();
      if (!context.mounted) return;
      if (name == null) return; // 用户取消
      showAppToast(context, '已导出：$name');
    } catch (e) {
      if (context.mounted) showAppToast(context, '导出失败：$e');
    }
  }

  // ── 导入：先选模式 ──
  void _pickImportMode(BuildContext context, LedgerViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择导入方式',
                  style: serifStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              const SizedBox(height: 6),
              const Text('导入全程在事务中执行，失败自动回滚，不会损坏现有数据。',
                  style: TextStyle(fontSize: 12, color: Palette.textSub)),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.merge_type_outlined,
                    color: Palette.income),
                title: const Text('合并导入'),
                subtitle: const Text('按账单编号去重，同编号覆盖；保留现有全部数据'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _import(context, vm, replaceAll: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined,
                    color: Palette.expense),
                title: const Text('覆盖导入',
                    style: TextStyle(color: Palette.expense)),
                subtitle: const Text('先清空现有账单与预算，再写入备份内容'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _confirmReplace(context, vm);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReplace(BuildContext context, LedgerViewModel vm) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: Palette.paper,
        title: Text('确认覆盖导入？',
            style: serifStyle.copyWith(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            '现有账单与预算将被全部清空后写入备份内容，此操作不可撤销。\n\n建议先「导出备份」留档。',
            style: TextStyle(fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('取消',
                style: TextStyle(color: Palette.textSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dlgCtx).pop();
              _import(context, vm, replaceAll: true);
            },
            style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Palette.expense),
            child: const Text('覆盖导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, LedgerViewModel vm,
      {required bool replaceAll}) async {
    try {
      final result = await vm.importBackup(replaceAll: replaceAll);
      if (!context.mounted) return;
      if (result == null) return; // 用户取消
      showAppToast(context,
          '导入完成：${result.bills} 笔账单 · ${result.budgets} 条预算');
    } on FormatException catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    } catch (e) {
      if (context.mounted) showAppToast(context, '导入失败：$e');
    }
  }

  // ── 自动备份恢复 ──
  Future<void> _autoRestore(BuildContext context, LedgerViewModel vm) async {
    final files = await vm.listAutoBackups();
    if (!context.mounted) return;
    if (files.isEmpty) {
      showAppToast(context, '暂无自动备份（记一笔后自动生成）');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('自动备份快照',
                  style: serifStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in files)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          p.basename(f.path) == 'latest.json'
                              ? Icons.auto_awesome_outlined
                              : Icons.event_note_outlined,
                          color: Palette.gold,
                        ),
                        title: Text(p.basename(f.path),
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '写入时间 ${_fileTime(f)}',
                          style: const TextStyle(
                              fontSize: 11, color: Palette.textSub),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          _restoreFromAuto(context, vm, f);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fileTime(File f) {
    try {
      final t = f.lastModifiedSync();
      return '${t.year}-${_two(t.month)}-${_two(t.day)} '
          '${_two(t.hour)}:${_two(t.minute)}';
    } catch (_) {
      return '未知';
    }
  }

  Future<void> _restoreFromAuto(
      BuildContext context, LedgerViewModel vm, File file) async {
    try {
      final dto = await vm.readAutoBackupFile(file);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: Palette.paper,
          title: Text('恢复此快照？',
              style: serifStyle.copyWith(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            '快照含 ${dto.meta.billCount} 笔账单 · ${dto.meta.budgetCount} 条预算'
            '（导出于 ${dto.meta.exportedAt}）。\n\n'
            '将以「覆盖」方式恢复：现有账单与预算会被清空。',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text('取消',
                  style: TextStyle(color: Palette.textSub)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Palette.expense),
              child: const Text('覆盖恢复'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final r = await vm.importBackupDto(dto, replaceAll: true);
      if (context.mounted) {
        showAppToast(context, '已恢复：${r.bills} 笔账单 · ${r.budgets} 条预算');
      }
    } on FormatException catch (e) {
      if (context.mounted) showAppToast(context, e.message);
    } catch (e) {
      if (context.mounted) showAppToast(context, '恢复失败：$e');
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
