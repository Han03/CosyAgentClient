import 'agent_message.dart';
import 'agent_state.dart';

/// Agent 运行结果：回答 + 完整推理轨迹 + 任务 ID。
/// 与服务端 AgentResult 字段对齐。
class AgentResult {
  final String sessionId;
  final String? answer;
  final AgentState state;
  final List<AgentMessage> trace;
  final int iterations;
  final int costMs;
  final String? errorMessage;
  final String? taskId;

  const AgentResult({
    required this.sessionId,
    this.answer,
    required this.state,
    this.trace = const [],
    this.iterations = 0,
    this.costMs = 0,
    this.errorMessage,
    this.taskId,
  });

  factory AgentResult.fromJson(Map<String, dynamic> json) => AgentResult(
        sessionId: json['sessionId'] as String? ?? '',
        answer: json['answer'] as String?,
        state: AgentState.fromWire(json['state'] as String?),
        trace: ((json['trace'] as List?) ?? const [])
            .map((e) => AgentMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        iterations: json['iterations'] as int? ?? 0,
        costMs: json['costMs'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        taskId: json['taskId'] as String?,
      );
}
