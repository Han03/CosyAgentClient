import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/agent_message.dart';
import '../../models/agent_task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/state_badge.dart';

/// 任务详情：主记录 + 轨迹时间线 + 断点恢复。
class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  bool _resuming = false;

  Future<void> _resume() async {
    setState(() => _resuming = true);
    try {
      final chat = await ref.read(chatRepositoryProvider.future);
      final result = await chat.resume(widget.taskId, '继续');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已产生新任务：${result.taskId}')),
      );
      setState(() => _resuming = false);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _resuming = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(taskDetailProvider(widget.taskId));
    return Scaffold(
      appBar: AppBar(title: Text('任务 ${widget.taskId}')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: const TextStyle(color: Colors.red)),
        ),
        data: (d) {
          final task = d.task;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(task: task),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('输入', style: TextStyle(fontSize: 12)),
                      Text(task.input ?? '-'),
                      const SizedBox(height: 8),
                      const Text('输出', style: TextStyle(fontSize: 12)),
                      Text(task.output ?? '-'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('执行轨迹（${d.trace.length} 条）',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...d.trace.map((m) => _TraceTile(message: m)),
              const SizedBox(height: 16),
              if (task.state.isTerminal)
                FilledButton.icon(
                  onPressed: _resuming ? null : _resume,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_resuming ? '执行中…' : '断点恢复（继续执行）'),
                ),
            ],
          );
        },
      ),
    );
  }
}

final taskDetailProvider =
    FutureProvider.autoDispose.family<dynamic, String>((ref, taskId) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.getTask(taskId);
});

class _Header extends StatelessWidget {
  final AgentTask task;

  const _Header({required this.task});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StateBadge(state: task.state),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '迭代 ${task.iterations} 次 · 耗时 ${task.costMs}ms',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _TraceTile extends StatelessWidget {
  final AgentMessage message;

  const _TraceTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final icon = switch (message.role) {
      'TOOL' => Icons.construction,
      'ASSISTANT' => Icons.smart_toy_outlined,
      _ => Icons.person_outline,
    };
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18),
      title: Text(
        message.isTool
            ? '工具 ${message.toolName}'
            : message.role,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        message.content ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
