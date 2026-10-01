/*
 * 模型管理平台化：设置页"模型管理"Tab 的数据模型。
 *
 * 后端为执行权威：本组模型仅用于管理台展示/编辑，不参与路由决策；
 * 路由规则（类型 → 有序候选链）与平台/模型规格均由后端持久化（Key 加密落库）。
 */

/// 平台摘要（列表）：api-key 仅掩码回显。
class ProviderSummary {
  final String name;
  final String baseUrl;
  final String completionsPath;
  final String type;
  final bool enabled;
  final bool apiKeyConfigured;
  final String maskedApiKey;
  final int timeoutMs;
  final int modelCount;

  const ProviderSummary({
    required this.name,
    required this.baseUrl,
    required this.completionsPath,
    required this.type,
    required this.enabled,
    required this.apiKeyConfigured,
    required this.maskedApiKey,
    required this.timeoutMs,
    required this.modelCount,
  });

  factory ProviderSummary.fromJson(Map<String, dynamic> json) {
    return ProviderSummary(
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      completionsPath: json['completionsPath'] as String? ?? '',
      type: json['type'] as String? ?? 'openai',
      enabled: json['enabled'] as bool? ?? true,
      apiKeyConfigured: json['apiKeyConfigured'] as bool? ?? false,
      maskedApiKey: json['maskedApiKey'] as String? ?? '',
      timeoutMs: json['timeoutMs'] as int? ?? 60000,
      modelCount: json['modelCount'] as int? ?? 0,
    );
  }
}

/// 平台下模型规格。
class ModelSpecInfo {
  final String modelId;
  final int contextWindow;
  final List<String> capabilities;

  const ModelSpecInfo({
    required this.modelId,
    required this.contextWindow,
    required this.capabilities,
  });

  factory ModelSpecInfo.fromJson(Map<String, dynamic> json) {
    return ModelSpecInfo(
      modelId: json['modelId'] as String? ?? '',
      contextWindow: json['contextWindow'] as int? ?? 0,
      capabilities: (json['capabilities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// 平台详情：摘要 + 模型规格完整元数据。
class ProviderDetail {
  final ProviderSummary summary;
  final List<ModelSpecInfo> models;

  const ProviderDetail({required this.summary, required this.models});

  factory ProviderDetail.fromJson(Map<String, dynamic> json) {
    final models = (json['models'] as List?)
            ?.map((e) => ModelSpecInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ModelSpecInfo>[];
    return ProviderDetail(
      summary: ProviderSummary(
        name: json['name'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        completionsPath: json['completionsPath'] as String? ?? '',
        type: json['type'] as String? ?? 'openai',
        enabled: json['enabled'] as bool? ?? true,
        apiKeyConfigured: json['apiKeyConfigured'] as bool? ?? false,
        maskedApiKey: json['maskedApiKey'] as String? ?? '',
        timeoutMs: json['timeoutMs'] as int? ?? 60000,
        modelCount: models.length,
      ),
      models: models,
    );
  }
}
