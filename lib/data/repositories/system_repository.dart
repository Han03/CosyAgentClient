import 'package:dio/dio.dart';

import '../../core/network/api_client.dart' as net;
import '../../models/capability_catalog.dart';
import '../../models/model_management.dart';

/// 系统仓库：状态 / 工具 / 健康检查 / 能力目录 / 模型管理（平台化）。
class SystemRepository {
  final Dio _dio;

  SystemRepository(this._dio);

  Future<Map<String, dynamic>> status() => net.getStatus(_dio);

  Future<List<String>> tools() => net.getToolNames(_dio);

  Future<Map<String, dynamic>> health() => net.getHealth(_dio);

  Future<List<CapabilitySummary>> capabilities() =>
      net.getCapabilityCatalog(_dio);

  // ---- 能力提供者管理（前端配置第三方能力） ----

  Future<List<CapabilityProviderSummary>> capabilityProviders() =>
      net.getCapabilityProviders(_dio);

  Future<CapabilityProviderDetail> capabilityProviderDetail(String providerId) =>
      net.getCapabilityProviderDetail(_dio, providerId);

  Future<String> createCapabilityProvider(Map<String, dynamic> body) =>
      net.createCapabilityProvider(_dio, body);

  Future<bool> updateCapabilityProvider(
          String providerId, Map<String, dynamic> body) =>
      net.updateCapabilityProvider(_dio, providerId, body);

  Future<bool> deleteCapabilityProvider(String providerId) =>
      net.deleteCapabilityProvider(_dio, providerId);

  // ---- 模型管理平台化 ----

  Future<List<ProviderSummary>> modelProviders() =>
      net.getModelProviders(_dio);

  Future<ProviderDetail> modelProviderDetail(String name) =>
      net.getModelProviderDetail(_dio, name);

  Future<bool> createModelProvider(String name, Map<String, dynamic> body) =>
      net.createModelProvider(_dio, name, body);

  Future<bool> updateModelProvider(String name, Map<String, dynamic> body) =>
      net.updateModelProvider(_dio, name, body);

  Future<bool> deleteModelProvider(String name) =>
      net.deleteModelProvider(_dio, name);

  Future<bool> addModelSpec(
          String name, String modelId, Map<String, dynamic> body) =>
      net.addModelSpec(_dio, name, modelId, body);

  Future<bool> updateModelSpec(
          String name, String modelId, Map<String, dynamic> body) =>
      net.updateModelSpec(_dio, name, modelId, body);

  Future<bool> deleteModelSpec(String name, String modelId) =>
      net.deleteModelSpec(_dio, name, modelId);

  Future<Map<String, List<String>>> modelRules() => net.getModelRules(_dio);

  Future<Map<String, dynamic>> updateModelRules(
          Map<String, List<String>> rules) =>
      net.updateModelRules(_dio, rules);

  Future<Map<String, dynamic>> testModelConnection(
          Map<String, dynamic> body) =>
      net.testModelConnection(_dio, body);
}
