import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/agent_task.dart';
import '../../models/task_detail.dart';

/// 任务仓库：详情、会话列表。
class TaskRepository {
  final Dio _dio;

  TaskRepository(this._dio);

  Future<TaskDetail> getTask(String taskId) => getTaskDetail(_dio, taskId);

  Future<List<AgentTask>> listTasks({String? sessionId, int limit = 20}) =>
      listTaskPage(_dio, sessionId: sessionId, limit: limit);
}
