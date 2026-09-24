import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/logging/cosy_logger.dart';
import '../models/session_selection.dart';
import '../models/session_summary.dart';
import '../providers/app_providers.dart';
import '../widgets/session_card.dart';

/// 响应式外壳：宽屏（≥900）桌面三栏式侧栏 + 内容区；窄屏底部导航。
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _destinations = [
    (icon: Icons.forum_outlined, label: '会话'),
    (icon: Icons.receipt_long_outlined, label: '任务'),
    (icon: Icons.book_outlined, label: '知识库'),
    (icon: Icons.settings_outlined, label: '设置'),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool? _lastWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      if (wide != _lastWide) {
        _lastWide = wide;
        if (wide) {
          // 窄→宽切换：路由若停留在移动端栈式 /chat/:id，回到桌面单实例 '/'。
          // 窄屏点击会话时已同步 currentSessionProvider，桌面页据此加载对应会话。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final uri = GoRouter.of(context).state.uri;
            if (uri.path.startsWith('/chat/')) {
              GoRouter.of(context).go('/');
            }
          });
        }
      }
      return wide ? _buildWide(context) : _buildNarrow(context);
    });
  }

  // ---- 桌面端：左侧会话栏 + 内容区 ----
  Widget _buildWide(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: _ConversationPane(
              onNav: (i) => widget.navigationShell.goBranch(i,
                  initialLocation: i == widget.navigationShell.currentIndex),
            ),
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          Expanded(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerLowest,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 移动端：内容区 + 底部导航 ----
  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (i) => widget.navigationShell.goBranch(i,
            initialLocation: i == widget.navigationShell.currentIndex),
        destinations: [
          for (final d in AppShell._destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

/// 桌面端左侧会话栏（品牌 + 新建 + 会话列表 + 快捷导航）。
class _ConversationPane extends ConsumerStatefulWidget {
  final ValueChanged<int> onNav;

  const _ConversationPane({required this.onNav});

  @override
  ConsumerState<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<_ConversationPane> {
  /// 置顶/取消置顶：调后端并刷新列表。
  Future<void> _togglePin(SessionSummary s) async {
    try {
      final repo = await ref.read(taskRepositoryProvider.future);
      await repo.pinSession(s.sessionId, pinned: !s.pinned);
    } catch (e) {
      CosyLogger.instance.error('ui', '置顶失败: $e');
    }
    ref.invalidate(sessionListProvider);
  }

  /// 重命名会话：对话框输入新标题，同步当前会话标题。
  Future<void> _renameSession(SessionSummary s) async {
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
    if (ref.read(currentSessionProvider)?.sessionId == s.sessionId) {
      ref.read(currentSessionProvider.notifier).state =
          SessionSelection(s.sessionId, title);
    }
    ref.invalidate(sessionListProvider);
  }

  /// 删除会话：确认后删除；若删除的是当前会话则回到空会话。
  Future<void> _deleteSession(SessionSummary s) async {
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
    if (ref.read(currentSessionProvider)?.sessionId == s.sessionId) {
      ref.read(currentSessionProvider.notifier).state =
          const SessionSelection(null, null);
    }
    ref.invalidate(sessionListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = ref.watch(sessionListProvider);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // 品牌区
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'CosyAgent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          // 新建会话：进入空会话界面，发送首条消息时才真正创建
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref
                    .read(currentSessionProvider.notifier)
                    .state = const SessionSelection(null, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建会话'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ),
          // 会话列表（后端 /api/agent/sessions，首条消息为标题）
          Expanded(
            child: sessions.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('加载失败：$e',
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.error)),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('暂无会话，点击上方新建',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return SessionCard(
                      title: s.title,
                      subtitle: s.sessionId,
                      selected: s.sessionId ==
                          ref.watch(currentSessionProvider)?.sessionId,
                      pinned: s.pinned,
                      onTap: () {
                        CosyLogger.instance.info(
                            'ui', 'list tap: ${s.sessionId} title=${s.title}');
                        ref
                            .read(currentSessionProvider.notifier)
                            .state = SessionSelection(s.sessionId, s.title);
                      },
                      onPin: () => _togglePin(s),
                      onRename: () => _renameSession(s),
                      onDelete: () => _deleteSession(s),
                    );
                  },
                );
              },
            ),
          ),
          // 底部快捷导航
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final (i, d) in [
                  (0, (icon: Icons.forum_outlined, label: '会话')),
                  (1, (icon: Icons.receipt_long_outlined, label: '任务')),
                  (2, (icon: Icons.book_outlined, label: '知识库')),
                  (3, (icon: Icons.settings_outlined, label: '设置')),
                ])
                  _NavButton(
                    icon: d.icon,
                    label: d.label,
                    selected: false,
                    onTap: () => widget.onNav(i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
