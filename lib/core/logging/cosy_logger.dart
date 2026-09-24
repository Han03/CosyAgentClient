import 'dart:async';

import 'package:flutter/foundation.dart';

import 'log_file.dart';
/// 日志级别（DEBUG < INFO < WARN < ERROR）。
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warn(2, 'WARN'),
  error(3, 'ERROR');

  final int rank;
  final String label;

  const LogLevel(this.rank, this.label);

  static LogLevel fromName(String? name) {
    return switch (name?.trim().toLowerCase()) {
      'debug' => LogLevel.debug,
      'warn' => LogLevel.warn,
      'error' => LogLevel.error,
      _ => LogLevel.info,
    };
  }
}

/// 日志门面：级别过滤、tag 定宽、文件持久化 + 调试镜像（debugPrint）。
///
/// 用法：`CosyLogger.instance.info('http', 'POST /api/agent/chat -> 200')`。
/// 日志目录解析见 [LogFile]；写入失败自动降级，不抛错。
class CosyLogger {
  CosyLogger._();

  static final CosyLogger instance = CosyLogger._();

  /// 启动日志目录（未初始化时为 null，此时仅镜像控制台）。
  String? get directory => _fileDir;

  String? _fileDir;

  LogLevel _level = LogLevel.fromName(
      const String.fromEnvironment('COSY_LOG_LEVEL', defaultValue: 'info'));

  LogFile _file = LogFile();

  /// 初始化文件通道（幂等）。
  Future<void> init() async {
    try {
      final dir = await _file.init();
      _fileDir = dir.path;
    } catch (_) {
      _fileDir = null;
    }
  }

  /// 测试注入：替换文件通道（单测可注入临时目录 LogFile）。
  @visibleForTesting
  void attachForTest(LogFile file, {LogLevel level = LogLevel.info}) {
    _file = file;
    _level = level;
    _fileDir = null;
  }

  void debug(String tag, String message) => _write(LogLevel.debug, tag, message);
  void info(String tag, String message) => _write(LogLevel.info, tag, message);
  void warn(String tag, String message) => _write(LogLevel.warn, tag, message);
  void error(String tag, String message, [Object? error, StackTrace? stack]) =>
      _write(LogLevel.error, tag, message, error: error, stack: stack);

  void _write(LogLevel level, String tag, String message,
      {Object? error, StackTrace? stack}) {
    if (level.rank < _level.rank) {
      return;
    }
    final now = DateTime.now();
    final line = _format(now, level, tag, message);
    if (kDebugMode) {
      debugPrint(line);
    }
    // 文件异步追加；error 附带堆栈
    unawaited(_persist(now, line, error, stack));
  }

  Future<void> _persist(
      DateTime now, String line, Object? error, StackTrace? stack) async {
    final buf = StringBuffer(line);
    if (error != null) {
      buf.writeln('  cause: $error');
    }
    if (stack != null) {
      buf.writeln('  ${stack.toString().split('\n').join('\n  ')}');
    }
    await _file.append(buf.toString(), now);
  }

  String _format(DateTime now, LogLevel level, String tag, String message) {
    String p2(int v) => v.toString().padLeft(2, '0');
    String p3(int v) => v.toString().padLeft(3, '0');
    final ts = '${now.year}-${p2(now.month)}-${p2(now.day)} '
        '${p2(now.hour)}:${p2(now.minute)}:${p2(now.second)}.${p3(now.millisecond)}';
    final t = tag.padRight(5).substring(0, 5);
    return '$ts ${level.label}  [$t] $message';
  }
}
