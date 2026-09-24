import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/agent_message.dart';
import '../../models/agent_result.dart';
import '../../models/agent_stream_event.dart';

/// 对话仓库：chat 与断点恢复。
class ChatRepository {
  final Dio _dio;

  ChatRepository(this._dio);

  Future<List<AgentMessage>> sessionMessages(String sessionId) =>
      getSessionMessages(_dio, sessionId);

Future<AgentResult> chat(String? sessionId, String message,
          {String modelChoice = 'auto'}) =>
      postChat(_dio, sessionId, message, modelChoice: modelChoice);

  /// 流式对话：实时事件流（thinking/tool/toolResult/answer/done/error）。
  Stream<AgentStreamEvent> chatStream(String? sessionId, String message,
          {String modelChoice = 'auto'}) =>
      streamChat(_dio, sessionId, message, modelChoice: modelChoice);

  Future<AgentResult> resume(String taskId, String message,
          {String modelChoice = 'auto'}) =>
      postResume(_dio, taskId, message, modelChoice: modelChoice);
}
