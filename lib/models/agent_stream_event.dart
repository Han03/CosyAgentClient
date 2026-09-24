/// SSE 流式事件（/api/agent/chat/stream）：与服务端 AgentStreamEvent 字段对齐。
/// type: thinking / tool / toolResult / answer / done / error
class AgentStreamEvent {
  final String type;
  final int? index; // thinking 事件：当前迭代轮次
  final String? callId; // tool / toolResult：工具调用 ID（用于配对）
  final String? toolName;
  final String? arguments; // tool：调用参数 JSON
  final String? content; // toolResult：观察结果 JSON；answer：回答文本
  final String? sessionId; // done：会话 ID
  final String? taskId; // done：任务 ID
  final String? state; // done：终态
  final int? iterations; // done
  final int? costMs; // done
  final String? errorMessage; // error / done(FAILED)
  final int? durationMs; // toolResult：工具执行耗时(ms)

  const AgentStreamEvent({
    required this.type,
    this.index,
    this.callId,
    this.toolName,
    this.arguments,
    this.content,
    this.sessionId,
    this.taskId,
    this.state,
    this.iterations,
    this.costMs,
    this.errorMessage,
    this.durationMs,
  });

  factory AgentStreamEvent.fromJson(Map<String, dynamic> json) =>
      AgentStreamEvent(
        type: json['type'] as String? ?? '',
        index: json['index'] as int?,
        callId: json['callId'] as String?,
        toolName: json['toolName'] as String?,
        arguments: json['arguments'] as String?,
        content: json['content'] as String?,
        sessionId: json['sessionId'] as String?,
        taskId: json['taskId'] as String?,
        state: json['state'] as String?,
        iterations: json['iterations'] as int?,
        costMs: json['costMs'] as int?,
        errorMessage: json['errorMessage'] as String?,
        durationMs: json['durationMs'] as int?,
      );
}
