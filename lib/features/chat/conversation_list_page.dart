import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/logging/cosy_logger.dart';
import '../../models/session_selection.dart';
import '../../models/session_summary.dart';
import '../../providers/app_providers.dart';
import '../../widgets/session_card.dart';

/// 会话列表（移动端首页）：后端会话列表 + 新建会话。
/// 新建仅进入空会话界面，发送首条消息时才真正创建会话。
class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(sessionListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('CosyAgent'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _refreshable(
          onRefresh: () async => ref.invalidate(sessionListProvider),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 40, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 10),
                Text('加载失败：$e',
                    style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                Text('下拉刷新重试',
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _refreshable(
              onRefresh: () async => ref.invalidate(sessionListProvider),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined,
                        size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('暂无会话，点击下方新建',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text('下拉刷新',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sessionListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 88),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                return SessionCard(
                  title: s.title,
                  subtitle: s.sessionId,
                  pinned: s.pinned,
                  onTap: () {
                    // 同步桌面单实例会话状态（窄→宽切换后由 provider 恢复）
                    ref.read(currentSessionProvider.notifier).state =
                        SessionSelection(s.sessionId, s.title);
                    context.push('/chat/${s.sessionId}', extra: s.title);
                  },
                  onPin: () => _togglePin(ref, s),
                  onRename: () => _renameSession(context, ref, s),
                  onDelete: () => _deleteSession(context, ref, s),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat/new'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新建会话'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }
}

/// 可下拉刷新的滚动容器：空态/错误态也能触发下拉刷新。
Widget _refreshable({
  required Future<void> Function() onRefresh,
  required Widget child,
}) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    ),
  );
}

/// 置顶/取消置顶（移动端）。
Future<void> _togglePin(WidgetRef ref, SessionSummary s) async {
  try {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.pinSession(s.sessionId, pinned: !s.pinned);
  } catch (e) {
    CosyLogger.instance.error('ui', '置顶失败: $e');
  }
  ref.invalidate(sessionListProvider);
}

/// 重命名会话（移动端）：对话框输入新标题。
Future<void> _renameSession(BuildContext context, WidgetRef ref,
    SessionSummary s) async {
  final controller = TextEditingController(text: s.title);
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重命名会话'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 1,
        decoration: const InputDecoration(hintText: '输入会话名称'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存')),
      ],
    ),
  );
  if (title == null || title.isEmpty) return;
  try {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.renameSession(s.sessionId, title);
  } catch (e) {
    CosyLogger.instance.error('ui', '重命名失败: $e');
  }
  ref.invalidate(sessionListProvider);
}

/// 删除会话（移动端）：确认后删除。
Future<void> _deleteSession(BuildContext context, WidgetRef ref,
    SessionSummary s) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除会话'),
      content: Text('确定删除会话「${s.title}」吗？该操作不可恢复。'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.deleteSession(s.sessionId);
  } catch (e) {
    CosyLogger.instance.error('ui', '删除会话失败: $e');
  }
  ref.invalidate(sessionListProvider);
}
