/// ReAct 结果渲染辅助：JSON 美化 / 超长截断 / 错误结果识别。
library;

import 'dart:convert';

/// JSON 字符串美化（工具参数/观察结果展示用）；非 JSON 原文返回。
String prettyJson(String raw) {
  if (raw.isEmpty) return raw;
  try {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}

/// 超长文本截断（展开卡内正文仍可全显）。
String truncateText(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

/// 工具观察结果是否为错误（JSON 含 error 键）。
bool isErrorResult(String content) {
  if (content.isEmpty) return false;
  try {
    final d = jsonDecode(content);
    return d is Map && d['error'] != null;
  } catch (_) {
    return false;
  }
}
