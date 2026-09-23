import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../models/agent_message.dart';
import '../../models/agent_task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/state_badge.dart';

/// 任务详情：主记录卡片 + 执行轨迹时间线 + 断点恢复。
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
    final theme = Theme.of(context);
    final detail = ref.watch(taskDetailProvider(widget.taskId));
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('加载失败：$e',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
            data: (d) {
              final task = d.task;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(task: task),
                  const SizedBox(height: 16),
                  Text('执行轨迹（${d.trace.length} 条）',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...d.trace.asMap().entries.map(
                      (e) => _TraceTile(index: e.key, message: e.value)),
                  const SizedBox(height: 20),
                  if (task.state.isTerminal)
                    GradientButton(
                      label: _resuming ? '执行中…' : '断点恢复（继续执行）',
                      icon: Icons.play_arrow_rounded,
                      loading: _resuming,
                      onPressed: _resume,
                      expanded: true,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final taskDetailProvider =
    FutureProvider.autoDispose.family<dynamic, String>((ref, taskId) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.getTask(taskId);
});

/// 主记录卡片：状态 + 输入/输出。
class _HeaderCard extends StatelessWidget {
  final AgentTask task;

  const _HeaderCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StateBadge(state: task.state),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '迭代 ${task.iterations} 次 · 耗时 ${task.costMs}ms',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('输入',
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(task.input ?? '-', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Text('输出',
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(task.output ?? '-',
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// 轨迹时间线条目。
class _TraceTile extends StatelessWidget {
  final int index;
  final AgentMessage message;

  const _TraceTile({required this.index, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, color) = switch (message.role) {
      'TOOL' => (
          Icons.construction,
          '工具调用 · ${message.toolName ?? ''}',
          theme.colorScheme.primary
        ),
      'ASSISTANT' => (
          Icons.smart_toy_outlined,
          'Agent 回复',
          theme.colorScheme.tertiary
        ),
      _ => (Icons.person_outline, '用户输入', theme.colorScheme.secondary),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 时间线竖线 + 节点
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.4),
                    ),
                    child: Icon(icon, size: 10, color: color),
                  ),
                  Expanded(
                    child: Container(
                      width: 1.6,
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color)),
                        const SizedBox(height: 4),
                        Text(
                          message.content ?? '',
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
