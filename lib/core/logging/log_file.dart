import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 日志文件通道：平台目录解析、按日命名、大小滚动、过期清理。
///
/// 目录策略：
/// - Windows：`%APPDATA%\com.cosy\cosy_agent_app\logs\`（与 flutter_secure_storage 同根）
/// - 移动端：应用文档目录 `.../logs/`
///
/// 命名：`cosy-YYYYMMDD.log`；单文件超 [maxBytes] 时滚动为 `cosy-YYYYMMDD-<seq>.log`。
class LogFile {
  static const int maxBytes = 5 * 1024 * 1024; // 单文件上限 5 MB
  static const int keepDays = 7; // 保留天数

  /// 测试注入：指定日志根目录（默认 null 走 path_provider 平台目录）。
  final Directory? overrideDir;

  LogFile({this.overrideDir});

  Directory? _dir;

  /// 解析平台日志目录并初始化（建目录、清理过期文件）。
  Future<Directory> init() async {
    if (_dir != null) {
      return _dir!;
    }
    final base = overrideDir ??
        await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}logs');
    await dir.create(recursive: true);
    await _cleanup(dir);
    _dir = dir;
    return dir;
  }

  /// 当前日志文件路径（按日命名，超限滚动 seq 后缀）。
  Future<String> resolvePath(DateTime now) async {
    final dir = await init();
    final day = _dayStamp(now);
    final base = File('${dir.path}${Platform.pathSeparator}cosy-$day.log');
    if (!base.existsSync() || base.lengthSync() < maxBytes) {
      return base.path;
    }
    // 超限：滚动为 cosy-YYYYMMDD-<seq>.log
    var seq = 1;
    while (true) {
      final next =
          File('${dir.path}${Platform.pathSeparator}cosy-$day-$seq.log');
      if (!next.existsSync() || next.lengthSync() < maxBytes) {
        return next.path;
      }
      seq++;
    }
  }

  /// 追加一行日志（同步写，失败降级不抛错）。
  Future<void> append(String line, DateTime now) async {
    try {
      final path = await resolvePath(now);
      final file = File(path);
      await file.writeAsString('$line\n',
          mode: FileMode.append, flush: true);
    } catch (_) {
      // 日志写入失败不影响主流程（debug 下由 CosyLogger 镜像到控制台）
    }
  }

  /// 清理超过 [keepDays] 的日志文件。
  Future<void> _cleanup(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      final stale = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();
      for (final f in stale) {
        final stat = await f.stat();
        if (stat.modified.isBefore(cutoff)) {
          await f.delete();
        }
      }
    } catch (_) {
      // 清理失败忽略
    }
  }

  static String _dayStamp(DateTime now) {
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${p2(now.month)}${p2(now.day)}';
  }
}
