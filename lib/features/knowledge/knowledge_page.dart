import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../models/knowledge_hit.dart';
import '../../providers/app_providers.dart';

/// 知识库：文档入库 + 向量检索（RAG）。
class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key});

  @override
  ConsumerState<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends ConsumerState<KnowledgePage> {
  final _namespace = TextEditingController();
  final _docId = TextEditingController();
  final _content = TextEditingController();
  final _query = TextEditingController();
  final _topK = TextEditingController(text: '3');

  List<KnowledgeHit> _hits = [];
  bool _busy = false;
  String? _message;

  Future<void> _upsert() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repo = await ref.read(knowledgeRepositoryProvider.future);
      final r = await repo.upsert(
        namespace: _namespace.text.isEmpty ? null : _namespace.text,
        docId: _docId.text.isEmpty ? null : _docId.text,
        content: _content.text,
      );
      if (!mounted) return;
      setState(() {
        _message = '入库成功：namespace=${r.namespace} docId=${r.docId} chunks=${r.chunks}';
        _busy = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '入库失败：${e is ApiException ? e.message : e}';
        _busy = false;
      });
    }
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repo = await ref.read(knowledgeRepositoryProvider.future);
      final hits = await repo.search(
        namespace: _namespace.text.isEmpty ? null : _namespace.text,
        query: _query.text,
        topK: int.tryParse(_topK.text),
      );
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _busy = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '检索失败：${e is ApiException ? e.message : e}';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _namespace.dispose();
    _docId.dispose();
    _content.dispose();
    _query.dispose();
    _topK.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('知识库（RAG）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('入库', style: TextStyle(fontWeight: FontWeight.w600)),
          TextField(
            controller: _namespace,
            decoration: const InputDecoration(labelText: 'namespace（可选）'),
          ),
          TextField(
            controller: _docId,
            decoration: const InputDecoration(labelText: 'docId（可选，自动生成）'),
          ),
          TextField(
            controller: _content,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'content（必填）'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _upsert,
            child: const Text('入库'),
          ),
          const Divider(height: 32),
          const Text('检索', style: TextStyle(fontWeight: FontWeight.w600)),
          TextField(
            controller: _query,
            decoration: const InputDecoration(labelText: 'query（必填）'),
          ),
          TextField(
            controller: _topK,
            decoration: const InputDecoration(labelText: 'topK（默认 3）'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _search,
            child: const Text('检索'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!, style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 16),
          ..._hits.map(
            (h) => Card(
              child: ListTile(
                title: Text(h.docId, style: const TextStyle(fontSize: 12)),
                subtitle: Text(h.content, maxLines: 3),
                trailing: Text('score ${h.score.toStringAsFixed(3)}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
