import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_page.dart';
import '../features/chat/conversation_list_page.dart';
import '../features/knowledge/knowledge_page.dart';
import '../features/settings/settings_page.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_list_page.dart';

/// 路由表：会话 / 对话 / 任务 / 任务详情 / 知识库 / 设置。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ConversationListPage()),
      GoRoute(
        path: '/chat/:sessionId',
        builder: (_, state) =>
            ChatPage(sessionId: state.pathParameters['sessionId'] ?? 's1'),
      ),
      GoRoute(path: '/tasks', builder: (_, _) => const TaskListPage()),
      GoRoute(
        path: '/tasks/:taskId',
        builder: (_, state) =>
            TaskDetailPage(taskId: state.pathParameters['taskId'] ?? ''),
      ),
      GoRoute(path: '/knowledge', builder: (_, _) => const KnowledgePage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  );
});
