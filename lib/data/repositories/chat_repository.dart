import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/agent_result.dart';

/// 对话仓库：chat 与断点恢复。
class ChatRepository {
  final Dio _dio;

  ChatRepository(this._dio);

  Future<AgentResult> chat(String sessionId, String message) =>
      postChat(_dio, sessionId, message);

  Future<AgentResult> resume(String taskId, String message) =>
      postResume(_dio, taskId, message);
}
