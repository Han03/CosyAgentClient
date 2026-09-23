import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/agent_task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/state_badge.dart';

/// 任务列表：全部任务（更新倒序）。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('任务列表')),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: const TextStyle(color: Colors.red)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无任务，先去对话吧'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final task = list[i] as AgentTask;
              return ListTile(
                leading: StateBadge(state: task.state),
                title: Text(task.input ?? task.taskId,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${task.taskId} · 迭代 ${task.iterations} · ${task.costMs}ms'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/tasks/${task.taskId}'),
              );
            },
          );
        },
      ),
    );
  }
}
