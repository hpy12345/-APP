import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 国风 Toast（复刻模拟版：浓墨底 + 描金边 + 宋体，1.6s 自动消失）
void showAppToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg,
          style: serifStyle.copyWith(
              fontSize: 13,
              letterSpacing: 1.2,
              color: Palette.goldSoft,
              fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
      backgroundColor: const Color(0xEB2B2521), // rgba(43,37,33,.92)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: Color(0x80B08D4F)),
      ),
    ));
}

/// 带撤销按钮的 Toast（删除撤销，方案 P0）
void showUndoToast(BuildContext context, String msg, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg,
          style: serifStyle.copyWith(
              fontSize: 13, letterSpacing: 1, color: Palette.goldSoft)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      backgroundColor: const Color(0xEB2B2521),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: Color(0x80B08D4F)),
      ),
      action: SnackBarAction(
        label: '撤销',
        textColor: Palette.gold,
        onPressed: onUndo,
      ),
    ));
}
