import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/knowledge_repository.dart';
import '../data/repositories/system_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/session_summary.dart';

/// 鉴权失效事件（401）：触发计数，供全局监听跳转设置页。
final authEventProvider = StateProvider<int>((_) => 0);

/// 网络层单例：baseUrl 来自设置（保存配置后 invalidate 重建），401 触发全局事件。
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final settings = await ref.read(settingsProvider.future);
  return ApiClient(
    baseUrl: settings.baseUrl,
    settingsLoader: () => ref.read(settingsProvider.future),
    onUnauthorized: () => ref.read(authEventProvider.notifier).state++,
  );
});

final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return ChatRepository(api.dio);
});

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return TaskRepository(api.dio);
});

final knowledgeRepositoryProvider =
    FutureProvider<KnowledgeRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return KnowledgeRepository(api.dio);
});

final systemRepositoryProvider = FutureProvider<SystemRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return SystemRepository(api.dio);
});

/// 任务列表（会话维度）。
final taskListProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.listTasks();
});

/// 会话列表（桌面左侧栏 / 移动首页共用；首条消息为标题，更新时间倒序）。
final sessionListProvider =
    FutureProvider.autoDispose<List<SessionSummary>>((ref) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.fetchSessions();
});
