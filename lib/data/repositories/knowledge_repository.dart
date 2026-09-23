import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/knowledge_hit.dart';

/// 知识库仓库：入库与检索（RAG）。
class KnowledgeRepository {
  final Dio _dio;

  KnowledgeRepository(this._dio);

  Future<KnowledgeUpsertResult> upsert(
          {String? namespace, String? docId, required String content}) =>
      upsertKnowledge(_dio, namespace: namespace, docId: docId, content: content);

  Future<List<KnowledgeHit>> search(
          {String? namespace, required String query, int? topK}) =>
      searchKnowledge(_dio, namespace: namespace, query: query, topK: topK);
}
