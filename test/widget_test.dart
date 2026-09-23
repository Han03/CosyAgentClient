import 'package:flutter_test/flutter_test.dart';

import 'package:cosy_agent_app/models/agent_result.dart';
import 'package:cosy_agent_app/models/agent_state.dart';
import 'package:cosy_agent_app/models/agent_task.dart';
import 'package:cosy_agent_app/models/task_detail.dart';

void main() {
  group('AgentState', () {
    test('wire 映射与服务端枚举一致', () {
      expect(AgentState.fromWire('COMPLETED'), AgentState.completed);
      expect(AgentState.fromWire('TOOL_CALLING'), AgentState.toolCalling);
      expect(AgentState.fromWire('UNKNOWN'), AgentState.init);
      expect(AgentState.completed.isTerminal, isTrue);
      expect(AgentState.running.isRunning, isTrue);
    });
  });

  group('AgentResult.fromJson', () {
    test('解析 chat 响应（含轨迹与 taskId）', () {
      final r = AgentResult.fromJson({
        'sessionId': 's1',
        'answer': '任务已完成',
        'state': 'COMPLETED',
        'iterations': 2,
        'costMs': 100,
        'taskId': 'task-1',
        'trace': [
          {
            'role': 'USER',
            'content': '现在几点？',
            'toolCallId': null,
            'toolName': null,
            'toolArguments': null,
            'timestamp': '2026-09-24T05:14:02Z'
          },
          {
            'role': 'TOOL',
            'content': '{"time":"10:00"}',
            'toolCallId': 'call-1',
            'toolName': 'get_server_time',
            'toolArguments': '{}',
            'timestamp': '2026-09-24T05:14:02Z'
          }
        ]
      });
      expect(r.state, AgentState.completed);
      expect(r.taskId, 'task-1');
      expect(r.trace, hasLength(2));
      expect(r.trace[1].isTool, isTrue);
      expect(r.trace[1].toolName, 'get_server_time');
    });
  });

  group('TaskDetail.fromJson', () {
    test('解析任务详情（主记录 + 轨迹）', () {
      final d = TaskDetail.fromJson({
        'task': {
          'taskId': 'task-1',
          'sessionId': 's1',
          'userId': 'anonymous',
          'state': 'FAILED',
          'input': '你好',
          'output': null,
          'iterations': 1,
          'costMs': 5,
          'errorMessage': '模型调用失败',
          'createdAt': '2026-09-24T05:00:00Z',
          'updatedAt': '2026-09-24T05:00:01Z',
          'finishedAt': null
        },
        'trace': [
          {'role': 'USER', 'content': '你好'}
        ]
      });
      expect(d.task.state, AgentState.failed);
      expect(d.task.errorMessage, '模型调用失败');
      expect(d.trace, hasLength(1));
      expect(d.trace[0].content, '你好');
    });
  });

  group('AgentTask.fromJson', () {
    test('任务列表字段解析', () {
      final t = AgentTask.fromJson({
        'taskId': 'task-2',
        'sessionId': 's1',
        'userId': 'u1',
        'state': 'TIMEOUT',
        'iterations': 8,
        'costMs': 1000
      });
      expect(t.state, AgentState.timeout);
      expect(t.iterations, 8);
    });
  });
}
