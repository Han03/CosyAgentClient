import 'agent_message.dart';
import 'agent_task.dart';

/// 任务详情：主记录 + 执行轨迹。
/// 与服务端 TaskStore.TaskDetail 对齐。
class TaskDetail {
  final AgentTask task;
  final List<AgentMessage> trace;

  const TaskDetail({required this.task, this.trace = const []});

  factory TaskDetail.fromJson(Map<String, dynamic> json) => TaskDetail(
        task: AgentTask.fromJson(json['task'] as Map<String, dynamic>),
        trace: ((json['trace'] as List?) ?? const [])
            .map((e) => AgentMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
