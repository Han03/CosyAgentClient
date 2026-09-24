import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/knowledge_repository.dart';
import '../data/repositories/system_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/model_catalog.dart';
import '../models/session_summary.dart';
import '../models/session_selection.dart';

/// 鉴权失效事件（401）：触发计数，供全局监听跳转设置页。
final authEventProvider = StateProvider<int>((_) => 0);

/// 当前会话选择（桌面单实例对话页）：列表点击 / 新建会话时更新，
/// ChatPage 监听并切换内容。null = 新会话（空会话界面）。
final currentSessionProvider =
    StateProvider<SessionSelection?>((_) => null);

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

/// 会话模型选择：'auto'（后端路由链）或 '平台/模型'（锁定单候选）。
/// 选择持久化到 cosy.defaultModel，聊天请求经 X-Cosy-Model 头下发。
final defaultModelProvider =
    StateNotifierProvider<DefaultModelNotifier, String>(
        (ref) => DefaultModelNotifier(ref));

class DefaultModelNotifier extends StateNotifier<String> {
  DefaultModelNotifier(this._ref) : super('auto');

  final Ref _ref;

  /// 启动/进入会话页时从本地存储恢复。
  Future<void> load() async {
    final settings = await _ref.read(settingsProvider.future);
    state = settings.defaultModel;
  }

  /// 选择并持久化。
  Future<void> select(String model) async {
    state = model;
    final settings = await _ref.read(settingsProvider.future);
    await _ref
        .read(settingsStoreProvider)
        .save(settings.copyWith(defaultModel: model));
  }
}

/// 模型路由目录（后端权威配置；拉取失败时选择器仅显示 Auto）。
final modelCatalogProvider =
    FutureProvider.autoDispose<ModelCatalog>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return getModelCatalog(api.dio);
});
