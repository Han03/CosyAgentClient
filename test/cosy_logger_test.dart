import 'dart:io';

import 'package:cosy_agent_app/core/logging/cosy_logger.dart';
import 'package:cosy_agent_app/core/logging/log_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late LogFile file;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cosy_log_test_');
    file = LogFile(overrideDir: temp);
  });

  tearDown(() async {
    try {
      await temp.delete(recursive: true);
    } catch (_) {}
  });

  test('LogLevel.fromName 解析', () {
    expect(LogLevel.fromName('debug'), LogLevel.debug);
    expect(LogLevel.fromName('warn'), LogLevel.warn);
    expect(LogLevel.fromName('ERROR'), LogLevel.error);
    expect(LogLevel.fromName(null), LogLevel.info);
    expect(LogLevel.fromName('xxx'), LogLevel.info);
  });

  test('按日命名写入日志文件', () async {
    final logger = CosyLogger.instance;
    logger.attachForTest(file);
    logger.info('http', 'REQ POST /api/agent/chat');

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final files = await temp
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.log'))
        .cast<File>()
        .toList();
    expect(files, hasLength(1));
    final now = DateTime.now();
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    expect(files.single.path, contains('cosy-$day.log'));
    final content = await files.single.readAsString();
    expect(content, contains('INFO'));
    expect(content, contains('[http')); // tag 定宽 5 字符，尾部补空格
    expect(content, contains('REQ POST /api/agent/chat'));
  });

  test('级别过滤：info 级别不落盘 debug', () async {
    final logger = CosyLogger.instance;
    logger.attachForTest(file); // 默认 info
    logger.debug('http', 'debug 行不应出现');
    logger.warn('http', 'warn 行应出现');

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final files = await temp
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.log'))
        .cast<File>()
        .toList();
    if (files.isEmpty) {
      fail('应生成日志文件');
    }
    final content = await files.single.readAsString();
    expect(content, isNot(contains('debug 行不应出现')));
    expect(content, contains('warn 行应出现'));
  });

  test('error 落盘附带 cause 与堆栈', () async {
    final logger = CosyLogger.instance;
    logger.attachForTest(file);
    logger.error('app', '连接失败', DioErrorLike('boom'));

    await Future<void>.delayed(const Duration(milliseconds: 300));
    final files = await temp
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.log'))
        .cast<File>()
        .toList();
    final content = await files.single.readAsString();
    expect(content, contains('ERROR'));
    expect(content, contains('cause: boom'));
  });

  test('超过单文件上限滚动 seq 后缀', () async {
    // 用小上限驱动滚动：先造满 5MB 文件（快速写入）
    final dir = await file.init();
    final now = DateTime.now();
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final base = File(
        '${dir.path}${Platform.pathSeparator}cosy-$day.log');
    await base.writeAsBytes(List.filled(LogFile.maxBytes, 0x20));

    final next = await file.resolvePath(DateTime.now());
    expect(next, isNot(base.path));
    expect(next, contains('cosy-$day-1.log'));
  });
}

/// 轻量异常占位（避免在日志单测中引入 Dio 依赖）。
class DioErrorLike implements Exception {
  final String message;
  DioErrorLike(this.message);

  @override
  String toString() => message;
}
