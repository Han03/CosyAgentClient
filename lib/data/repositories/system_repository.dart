import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

/// 系统仓库：状态 / 工具 / 健康检查。
class SystemRepository {
  final Dio _dio;

  SystemRepository(this._dio);

  Future<Map<String, dynamic>> status() => getStatus(_dio);

  Future<List<String>> tools() => getToolNames(_dio);

  Future<Map<String, dynamic>> health() => getHealth(_dio);
}
