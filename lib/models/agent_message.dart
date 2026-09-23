/// 对话消息单元：ReAct 轨迹（推理链）与多轮对话的统一载体。
/// 与服务端 AgentMessage 字段对齐。
class AgentMessage {
  final String role; // SYSTEM / USER / ASSISTANT / TOOL
  final String? content;
  final String? toolCallId;
  final String? toolName;
  final String? toolArguments;
  final String? timestamp;

  const AgentMessage({
    required this.role,
    this.content,
    this.toolCallId,
    this.toolName,
    this.toolArguments,
    this.timestamp,
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) => AgentMessage(
        role: json['role'] as String? ?? '',
        content: json['content'] as String?,
        toolCallId: json['toolCallId'] as String?,
        toolName: json['toolName'] as String?,
        toolArguments: json['toolArguments'] as String?,
        timestamp: json['timestamp'] as String?,
      );

  bool get isTool => role == 'TOOL';
}
