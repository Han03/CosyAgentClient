import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/agent_result.dart';
import '../../models/agent_task.dart';
import '../../models/knowledge_hit.dart';
import '../../models/task_detail.dart';
import 'api_exception.dart';

/// 客户端运行配置：服务地址与 API Key。
/// 默认值经 --dart-define 注入（COSY_BASE_URL / COSY_API_KEY），运行时可修改。
class AppSettings {
  static const _baseUrlDefault =
      String.fromEnvironment('COSY_BASE_URL', defaultValue: 'http://localhost:8080');
  static const _apiKeyDefault =
      String.fromEnvironment('COSY_API_KEY', defaultValue: '');

  final String baseUrl;
  final String apiKey;

  const AppSettings({required this.baseUrl, required this.apiKey});

  factory AppSettings.defaults() =>
      AppSettings(baseUrl: _baseUrlDefault, apiKey: _apiKeyDefault);
}

/// 持久化运行配置（baseUrl 内存态 + apiKey 安全存储）。
class SettingsStore {
  final _secure = const FlutterSecureStorage();

  static const _keyBaseUrl = 'cosy.baseUrl';
  static const _keyApiKey = 'cosy.apiKey';

  Future<AppSettings> load() async {
    final baseUrl =
        await _secure.read(key: _keyBaseUrl) ?? AppSettings.defaults().baseUrl;
    final apiKey = await _secure.read(key: _keyApiKey) ?? '';
    return AppSettings(baseUrl: baseUrl, apiKey: apiKey);
  }

  Future<void> save(AppSettings settings) async {
    await _secure.write(key: _keyBaseUrl, value: settings.baseUrl);
    if (settings.apiKey.isNotEmpty) {
      await _secure.write(key: _keyApiKey, value: settings.apiKey);
    } else {
      await _secure.delete(key: _keyApiKey);
    }
  }
}

final settingsStoreProvider = Provider<SettingsStore>((_) => SettingsStore());

/// 当前运行配置（从安全存储加载）。
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsStoreProvider).load();
});

/// 网络层统一入口：Dio + 拦截器链（Auth → Error → Log）。
class ApiClient {
  final Dio _dio;
  final Future<AppSettings> Function() _settingsLoader;
  final void Function() _onUnauthorized;

  ApiClient({
    required this._settingsLoader,
    required this._onUnauthorized,
  })  : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          responseType: ResponseType.json,
        )) {
    _dio.interceptors.add(_AuthInterceptor(_settingsLoader));
    _dio.interceptors.add(_ErrorInterceptor(_onUnauthorized));
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (o) => debugLog(o),
    ));
  }

  static void debugLog(Object? o) {
    // 统一日志出口：生产可替换为正式 Logger；此处保持极简。
    assert(() {
      // ignore: avoid_print
      print(o);
      return true;
    }());
  }

  Dio get dio => _dio;
}

/// 鉴权拦截器：从设置注入 X-API-Key（未配置不注入）。
class _AuthInterceptor extends Interceptor {
  final Future<AppSettings> Function() _settingsLoader;

  _AuthInterceptor(this._settingsLoader);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final settings = await _settingsLoader();
    if (settings.apiKey.isNotEmpty) {
      options.headers['X-API-Key'] = settings.apiKey;
    }
    handler.next(options);
  }
}

/// 错误拦截器：统一解包 `Result<T>`（code==0 取 data，否则抛 ApiException）。
class _ErrorInterceptor extends Interceptor {
  final void Function() _onUnauthorized;

  _ErrorInterceptor(this._onUnauthorized);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final code = body['code'] as int? ?? 0;
      if (code != 0) {
        final message = body['message'] as String? ?? '未知错误';
        if (code == 401) {
          _onUnauthorized();
          handler.reject(DioException.connectionError(
              requestOptions: response.requestOptions,
              reason: message,
              error: UnauthorizedException(message)));
          return;
        }
        handler.reject(DioException(
            requestOptions: response.requestOptions,
            type: DioExceptionType.badResponse,
            error: ApiException(code, message)));
        return;
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = err.error;
    if (error is ApiException) {
      handler.reject(DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          error: error));
      return;
    }
    final mapped = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        const ApiException(-1, '请求超时，请检查服务地址与网络', isNetwork: true),
      DioExceptionType.connectionError =>
        const ApiException(-2, '无法连接服务端，请检查服务是否启动', isNetwork: true),
      _ => ApiException(-3, err.message ?? '网络请求失败', isNetwork: true),
    };
    handler.reject(DioException(
        requestOptions: err.requestOptions, type: err.type, error: mapped));
  }
}

/// 服务端统一响应解包：code==0 取 data，否则抛 ApiException。
T unwrap<T>(dynamic body, T Function(Map<String, dynamic>) mapper) {
  if (body is! Map<String, dynamic>) {
    throw const ApiException(-3, '响应格式异常');
  }
  final code = body['code'] as int? ?? 0;
  if (code != 0) {
    throw ApiException(code, body['message'] as String? ?? '未知错误');
  }
  final data = body['data'];
  if (data is! Map<String, dynamic>) {
    throw const ApiException(-3, '响应缺少 data');
  }
  return mapper(data);
}

/// 便捷：列表 data（data 为数组）。
List<T> unwrapList<T>(
    dynamic body, T Function(Map<String, dynamic>) mapper) {
  if (body is! Map<String, dynamic>) {
    throw const ApiException(-3, '响应格式异常');
  }
  final code = body['code'] as int? ?? 0;
  if (code != 0) {
    throw ApiException(code, body['message'] as String? ?? '未知错误');
  }
  final list = body['data'];
  if (list is! List) {
    throw const ApiException(-3, '响应缺少 data 列表');
  }
  return list.map((e) => mapper(e as Map<String, dynamic>)).toList();
}

// 以下为各仓库直接调用的网络入口（保持 Repository 与 Dio 隔离）。

typedef JsonMap = Map<String, dynamic>;

Future<AgentResult> postChat(Dio dio, String sessionId, String message) async {
  final resp = await dio.post<Map<String, dynamic>>(
      '/api/agent/chat', data: {'sessionId': sessionId, 'message': message});
  return unwrap(resp.data, AgentResult.fromJson);
}

Future<AgentResult> postResume(Dio dio, String taskId, String message) async {
  final resp = await dio.post<Map<String, dynamic>>(
      '/api/agent/tasks/$taskId/resume', data: {'message': message});
  return unwrap(resp.data, AgentResult.fromJson);
}

Future<TaskDetail> getTaskDetail(Dio dio, String taskId) async {
  final resp = await dio.get<Map<String, dynamic>>('/api/agent/tasks/$taskId');
  return unwrap(resp.data, TaskDetail.fromJson);
}

Future<List<AgentTask>> listTaskPage(
    Dio dio, {String? sessionId, int limit = 20}) async {
  final resp = await dio.get<Map<String, dynamic>>('/api/agent/tasks',
      queryParameters: {
        if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
        'limit': limit,
      });
  return unwrapList(resp.data, AgentTask.fromJson);
}

Future<KnowledgeUpsertResult> upsertKnowledge(
    Dio dio, {String? namespace, String? docId, required String content}) async {
  final resp = await dio.post<Map<String, dynamic>>(
      '/api/agent/knowledge/upsert',
      data: {
        if (namespace != null && namespace.isNotEmpty) 'namespace': namespace,
        if (docId != null && docId.isNotEmpty) 'docId': docId,
        'content': content,
      });
  return unwrap(resp.data, KnowledgeUpsertResult.fromJson);
}

Future<List<KnowledgeHit>> searchKnowledge(
    Dio dio, {String? namespace, required String query, int? topK}) async {
  final resp = await dio.post<Map<String, dynamic>>(
      '/api/agent/knowledge/search',
      data: {
        if (namespace != null && namespace.isNotEmpty) 'namespace': namespace,
        'query': query,
        // ignore: use_null_aware_elements`n        if (topK != null) 'topK': topK,
      });
  return unwrapList(resp.data, KnowledgeHit.fromJson);
}

Future<JsonMap> getStatus(Dio dio) async {
  final resp = await dio.get<Map<String, dynamic>>('/api/agent/status');
  return unwrap(resp.data, (d) => d);
}

Future<List<String>> getToolNames(Dio dio) async {
  final resp = await dio.get<Map<String, dynamic>>('/api/agent/tools');
  final data = resp.data;
  if (data is! Map<String, dynamic>) {
    throw const ApiException(-3, '响应格式异常');
  }
  final list = data['data'];
  if (list is! List) {
    throw const ApiException(-3, '响应缺少 data 列表');
  }
  return list.map((e) => e.toString()).toList();
}

Future<JsonMap> getHealth(Dio dio) async {
  final resp = await dio.get<Map<String, dynamic>>('/actuator/health');
  return resp.data ?? {};
}
