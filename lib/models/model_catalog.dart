import 'dart:convert';

/// 模型路由目录（后端管理 API /api/agent/model-routing/catalog 返回）。
class ModelCatalog {
  final bool autoEnabled;
  final List<String> models;
  final List<String> routeTypes;

  const ModelCatalog({
    required this.autoEnabled,
    required this.models,
    required this.routeTypes,
  });

  factory ModelCatalog.fromJson(Map<String, dynamic> json) => ModelCatalog(
        autoEnabled: json['auto'] as bool? ?? true,
        models: (json['models'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        routeTypes: (json['routeTypes'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  @override
  String toString() => jsonEncode({
        'auto': autoEnabled,
        'models': models,
        'routeTypes': routeTypes,
      });
}
