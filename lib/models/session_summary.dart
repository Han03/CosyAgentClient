import 'agent_state.dart';

/// 会话摘要：与服务端 TaskStore.SessionSummary 对齐（会话 = sessionId 分组）。
class SessionSummary {
  final String sessionId;
  final String title;
  final AgentState state;
  final String? updatedAt;

  const SessionSummary({
    required this.sessionId,
    required this.title,
    required this.state,
    this.updatedAt,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        sessionId: json['sessionId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        state: AgentState.fromWire(json['state'] as String?),
        updatedAt: json['updatedAt'] as String?,
      );
}
