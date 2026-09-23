import 'agent_state.dart';

/// 任务主记录：一次 Agent 运行在持久化层的投影。
/// 与服务端 AgentTask 字段对齐。
class AgentTask {
  final String taskId;
  final String sessionId;
  final String userId;
  final AgentState state;
  final String? input;
  final String? output;
  final int iterations;
  final int costMs;
  final String? errorMessage;
  final String? createdAt;
  final String? updatedAt;
  final String? finishedAt;

  const AgentTask({
    required this.taskId,
    required this.sessionId,
    required this.userId,
    required this.state,
    this.input,
    this.output,
    this.iterations = 0,
    this.costMs = 0,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
    this.finishedAt,
  });

  factory AgentTask.fromJson(Map<String, dynamic> json) => AgentTask(
        taskId: json['taskId'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        state: AgentState.fromWire(json['state'] as String?),
        input: json['input'] as String?,
        output: json['output'] as String?,
        iterations: json['iterations'] as int? ?? 0,
        costMs: json['costMs'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
        finishedAt: json['finishedAt'] as String?,
      );
}
