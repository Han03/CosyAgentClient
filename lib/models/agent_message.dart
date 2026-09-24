/// 对话消息单元：ReAct 轨迹（推理链）与多轮对话的统一载体。
/// 与服务端 AgentMessage 字段对齐。
class AgentMessage {
  final String role; // SYSTEM / USER / ASSISTANT / TOOL
  final String? content;
  final String? toolCallId;
  final String? toolName;
  final String? toolArguments;
  final String? timestamp;
  final int? durationMs; // 工具执行耗时(ms)：流式 toolResult 事件透传，历史消息为 null

  const AgentMessage({
    required this.role,
    this.content,
    this.toolCallId,
    this.toolName,
    this.toolArguments,
    this.timestamp,
    this.durationMs,
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) => AgentMessage(
        role: json['role'] as String? ?? '',
        content: json['content'] as String?,
        toolCallId: json['toolCallId'] as String?,
        toolName: json['toolName'] as String?,
        toolArguments: json['toolArguments'] as String?,
        timestamp: json['timestamp'] as String?,
        durationMs: json['durationMs'] as int?,
      );

  bool get isTool => role == 'TOOL';
}
