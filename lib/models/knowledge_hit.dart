/// 知识库检索命中。
/// 与服务端 VectorKnowledgeStore.KnowledgeHit 对齐。
class KnowledgeHit {
  final String docId;
  final String content;
  final double score;

  const KnowledgeHit({
    required this.docId,
    required this.content,
    required this.score,
  });

  factory KnowledgeHit.fromJson(Map<String, dynamic> json) => KnowledgeHit(
        docId: json['docId'] as String? ?? '',
        content: json['content'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

/// 知识入库结果。
class KnowledgeUpsertResult {
  final String namespace;
  final String docId;
  final int chunks;

  const KnowledgeUpsertResult({
    required this.namespace,
    required this.docId,
    required this.chunks,
  });

  factory KnowledgeUpsertResult.fromJson(Map<String, dynamic> json) =>
      KnowledgeUpsertResult(
        namespace: json['namespace'] as String? ?? '',
        docId: json['docId'] as String? ?? '',
        chunks: json['chunks'] as int? ?? 0,
      );
}
