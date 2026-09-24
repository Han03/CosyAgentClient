import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
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
        error: (e, _) => Center(
          child: Text('加载失败：$e',
              style: TextStyle(color: theme.colorScheme.error)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined,
                      size: 56, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('暂无会话，点击下方新建',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
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
                  onTap: () => context.push('/chat/${s.sessionId}',
                      extra: s.title),
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
