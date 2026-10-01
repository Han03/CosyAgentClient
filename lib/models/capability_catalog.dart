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

  const CapabilityInstance({
    required this.providerId,
    required this.appName,
    required this.baseUrl,
    required this.mode,
    required this.endpointMode,
    required this.status,
  });

  factory CapabilityInstance.fromJson(Map<String, dynamic> json) {
    return CapabilityInstance(
      providerId: json['providerId']?.toString() ?? '',
      appName: json['appName']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'ap',
      endpointMode: json['endpointMode']?.toString() ?? 'sync',
      status: json['status']?.toString() ?? 'UNKNOWN',
    );
  }

  bool get isUp => status == 'UP';
}
