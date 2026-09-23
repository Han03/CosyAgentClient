import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_page.dart';
import '../features/chat/conversation_list_page.dart';
import '../features/knowledge/knowledge_page.dart';
import '../features/settings/settings_page.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_list_page.dart';
import 'shell.dart';

/// 路由表：响应式外壳（桌面侧栏 / 移动底栏）+ 四个分支页面。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 会话：列表 + 对话
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const ConversationListPage(),
              routes: [
                GoRoute(
                  path: 'chat/:sessionId',
                  builder: (_, state) => ChatPage(
                      sessionId: state.pathParameters['sessionId'] ?? 's1'),
                ),
              ],
            ),
          ]),
          // 任务：列表 + 详情
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasks',
              builder: (_, _) => const TaskListPage(),
              routes: [
                GoRoute(
                  path: ':taskId',
                  builder: (_, state) => TaskDetailPage(
                      taskId: state.pathParameters['taskId'] ?? ''),
                ),
              ],
            ),
          ]),
          // 知识库
          StatefulShellBranch(routes: [
            GoRoute(path: '/knowledge', builder: (_, _) => const KnowledgePage()),
          ]),
          // 设置
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ]),
        ],
      ),
    ],
  );
});
