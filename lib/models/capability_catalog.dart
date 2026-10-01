/// 能力注册中心目录模型（GET /api/agent/capabilities，脱敏：不含 callToken）。
class CapabilitySummary {
  final String name;
  final String description;
  final List<CapabilityInstance> instances;

  const CapabilitySummary({
    required this.name,
    required this.description,
    required this.instances,
  });

  factory CapabilitySummary.fromJson(Map<String, dynamic> json) {
    final raw = json['instances'];
    return CapabilitySummary(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instances: raw is List
          ? raw
              .map((e) => CapabilityInstance.fromJson(
                  e is Map<String, dynamic> ? e : const {}))
              .toList()
          : const [],
    );
  }
}

/// 能力的一个提供者实例（候选链成员）。
class CapabilityInstance {
  final String providerId;
  final String appName;
  final String baseUrl;
  final String mode; // ap | cp
  final String endpointMode; // sync | submit-poll
  final String status; // UP | SUSPECT | DOWN
  final String authModel; // none | bearer | header | query
  final String source; // external | console

  const CapabilityInstance({
    required this.providerId,
    required this.appName,
    required this.baseUrl,
    required this.mode,
    required this.endpointMode,
    required this.status,
    this.authModel = 'none',
    this.source = 'external',
  });

  factory CapabilityInstance.fromJson(Map<String, dynamic> json) {
    return CapabilityInstance(
      providerId: json['providerId']?.toString() ?? '',
      appName: json['appName']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'ap',
      endpointMode: json['endpointMode']?.toString() ?? 'sync',
      status: json['status']?.toString() ?? 'UNKNOWN',
      authModel: json['authModel']?.toString() ?? 'none',
      source: json['source']?.toString() ?? 'external',
    );
  }

  bool get isUp => status == 'UP';
}

/// 提供者管理摘要（GET /api/agent/capabilities/providers，密钥掩码回显）。
class CapabilityProviderSummary {
  final String providerId;
  final String appName;
  final String baseUrl;
  final String mode; // ap | cp
  final String status;
  final String source; // external | console
  final String authModel; // none | bearer | header | query
  final String authHeaderName;
  final String authParamName;
  final String authValueMasked;
  final int capabilityCount;

  const CapabilityProviderSummary({
    required this.providerId,
    required this.appName,
    required this.baseUrl,
    required this.mode,
    required this.status,
    required this.source,
    required this.authModel,
    required this.authHeaderName,
    required this.authParamName,
    required this.authValueMasked,
    required this.capabilityCount,
  });

  factory CapabilityProviderSummary.fromJson(Map<String, dynamic> json) {
    return CapabilityProviderSummary(
      providerId: json['providerId']?.toString() ?? '',
      appName: json['appName']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'cp',
      status: json['status']?.toString() ?? 'UNKNOWN',
      source: json['source']?.toString() ?? 'external',
      authModel: json['authModel']?.toString() ?? 'none',
      authHeaderName: json['authHeaderName']?.toString() ?? '',
      authParamName: json['authParamName']?.toString() ?? '',
      authValueMasked: json['authValueMasked']?.toString() ?? '',
      capabilityCount: json['capabilityCount'] as int? ?? 0,
    );
  }

  bool get isUp => status == 'UP';
}

/// 能力定义（提供者详情回显 / 前端编辑器共用）。
class CapabilityDefinition {
  final String name;
  final String description;
  final Map<String, String> parameters;
  final String endpointPath;
  final String endpointMethod; // GET | POST
  final bool retryable;
  final String endpointMode; // sync | submit-poll
  final String? statusPath;
  final String? resultPath;
  final int? pollIntervalMs;
  final int? pollTimeoutMs;

  const CapabilityDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.endpointPath,
    required this.endpointMethod,
    required this.retryable,
    required this.endpointMode,
    this.statusPath,
    this.resultPath,
    this.pollIntervalMs,
    this.pollTimeoutMs,
  });

  factory CapabilityDefinition.fromJson(Map<String, dynamic> json) {
    final params = json['parameters'];
    return CapabilityDefinition(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      parameters: params is Map
          ? params.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      endpointPath: json['endpointPath']?.toString() ?? '',
      endpointMethod: json['endpointMethod']?.toString() ?? 'GET',
      retryable: json['retryable'] as bool? ?? false,
      endpointMode: json['endpointMode']?.toString() ?? 'sync',
      statusPath: json['statusPath']?.toString(),
      resultPath: json['resultPath']?.toString(),
      pollIntervalMs: json['pollIntervalMs'] as int?,
      pollTimeoutMs: json['pollTimeoutMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'parameters': parameters,
        'endpointPath': endpointPath,
        'endpointMethod': endpointMethod,
        'retryable': retryable,
        'endpointMode': endpointMode,
        if (statusPath != null && statusPath!.isNotEmpty)
          'statusPath': statusPath,
        if (resultPath != null && resultPath!.isNotEmpty)
          'resultPath': resultPath,
        if (pollIntervalMs != null) 'pollIntervalMs': pollIntervalMs,
        if (pollTimeoutMs != null) 'pollTimeoutMs': pollTimeoutMs,
      };
}

/// 提供者详情（编辑回显）：摘要 + 能力完整定义。
class CapabilityProviderDetail {
  final CapabilityProviderSummary summary;
  final List<CapabilityDefinition> capabilities;

  const CapabilityProviderDetail({
    required this.summary,
    required this.capabilities,
  });

  factory CapabilityProviderDetail.fromJson(Map<String, dynamic> json) {
    final caps = (json['capabilities'] as List?)
            ?.map((e) =>
                CapabilityDefinition.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <CapabilityDefinition>[];
    return CapabilityProviderDetail(
      summary: CapabilityProviderSummary(
        providerId: json['providerId']?.toString() ?? '',
        appName: json['appName']?.toString() ?? '',
        baseUrl: json['baseUrl']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'cp',
        status: json['status']?.toString() ?? 'UNKNOWN',
        source: json['source']?.toString() ?? 'external',
        authModel: json['authModel']?.toString() ?? 'none',
        authHeaderName: json['authHeaderName']?.toString() ?? '',
        authParamName: json['authParamName']?.toString() ?? '',
        authValueMasked: json['authValueMasked']?.toString() ?? '',
        capabilityCount: caps.length,
      ),
      capabilities: caps,
    );
  }
}
